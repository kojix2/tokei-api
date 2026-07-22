require "../config/database"
require "./analysis"

module Tokei::Api::Models
  # Tracks recent repository analysis failures so repeated badge reads do not
  # keep triggering expensive fetch and tokei work for the same repository.
  class AnalysisFailure
    def self.backoff_for(failure_count : Int32) : Time::Span
      case failure_count
      when 1 then 5.minutes
      when 2 then 30.minutes
      else        6.hours
      end
    end

    def self.suppressed_until(repo_url : String) : Time?
      conn = Tokei::Api::Config::Database.connection
      begin
        conn.query_one?(
          "SELECT retry_after FROM analysis_failures WHERE repo_url = ? AND retry_after > ?",
          repo_url,
          Analysis.timestamp(Time.utc),
          as: String
        ).try { |value| Time.parse_rfc3339(value) }
      ensure
        conn.close
      end
    end

    def self.record(repo_url : String, error_type : String) : {Int32, Time}
      conn = Tokei::Api::Config::Database.connection
      begin
        current = conn.query_one?(
          "SELECT failure_count FROM analysis_failures WHERE repo_url = ?",
          repo_url,
          as: Int64
        )
        failure_count = (current.try(&.to_i32) || 0) + 1
        now = Time.utc
        retry_after = now + backoff_for(failure_count)

        conn.exec(
          "INSERT OR REPLACE INTO analysis_failures " \
          "(repo_url, failure_count, error_type, last_failed_at, retry_after) " \
          "VALUES (?, ?, ?, ?, ?)",
          repo_url,
          failure_count,
          error_type,
          Analysis.timestamp(now),
          Analysis.timestamp(retry_after)
        )

        {failure_count, retry_after}
      ensure
        conn.close
      end
    end

    def self.clear(repo_url : String) : Nil
      conn = Tokei::Api::Config::Database.connection
      begin
        conn.exec("DELETE FROM analysis_failures WHERE repo_url = ?", repo_url)
      ensure
        conn.close
      end
    end

    def self.cleanup_old_data : Int64
      conn = Tokei::Api::Config::Database.connection
      begin
        conn.exec(
          "DELETE FROM analysis_failures WHERE retry_after < ?",
          Analysis.timestamp(Time.utc)
        ).rows_affected
      ensure
        conn.close
      end
    end
  end
end
