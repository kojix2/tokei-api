require "spec"

ENV["CACHE_DB_PATH"] = "/tmp/tokei-api-analysis-failure-spec.sqlite3"

require "../../src/config/database"
require "../../src/models/analysis"
require "../../src/models/analysis_failure"

private def reset_failure_cache_db
  Tokei::Api::Config::Database.setup

  conn = Tokei::Api::Config::Database.connection
  begin
    conn.exec("DELETE FROM analysis_failures")
    conn.exec("DELETE FROM analyses")
  ensure
    conn.close
  end
end

private def seconds_from_now(time : Time) : Float64
  (time - Time.utc).total_seconds
end

describe Tokei::Api::Models::AnalysisFailure do
  before_each do
    reset_failure_cache_db
  end

  after_all do
    db_path = Tokei::Api::Config::Database::CACHE_DB_PATH
    [db_path, "#{db_path}-wal", "#{db_path}-shm"].each do |path|
      File.delete(path) if File.exists?(path)
    end
  end

  it "records the first failure with a five minute backoff" do
    count, retry_after = Tokei::Api::Models::AnalysisFailure.record("https://github.com/kojix2/tokei-api", "clone_failed")

    count.should eq(1)
    seconds_from_now(retry_after).should be_close(5.minutes.total_seconds, 3.0)
  end

  it "records the second failure with a thirty minute backoff" do
    repo_url = "https://github.com/kojix2/tokei-api"

    Tokei::Api::Models::AnalysisFailure.record(repo_url, "clone_failed")
    count, retry_after = Tokei::Api::Models::AnalysisFailure.record(repo_url, "clone_failed")

    count.should eq(2)
    seconds_from_now(retry_after).should be_close(30.minutes.total_seconds, 3.0)
  end

  it "records the third and later failures with a six hour backoff" do
    repo_url = "https://github.com/kojix2/tokei-api"

    2.times { Tokei::Api::Models::AnalysisFailure.record(repo_url, "clone_failed") }
    count, retry_after = Tokei::Api::Models::AnalysisFailure.record(repo_url, "clone_failed")

    count.should eq(3)
    seconds_from_now(retry_after).should be_close(6.hours.total_seconds, 3.0)
  end

  it "returns suppression while active and nil after clear" do
    repo_url = "https://github.com/kojix2/tokei-api"

    Tokei::Api::Models::AnalysisFailure.record(repo_url, "clone_failed")
    Tokei::Api::Models::AnalysisFailure.suppressed_until(repo_url).should_not be_nil

    Tokei::Api::Models::AnalysisFailure.clear(repo_url)
    Tokei::Api::Models::AnalysisFailure.suppressed_until(repo_url).should be_nil
  end

  it "keeps failure counts independent per repository" do
    first_repo = "https://github.com/kojix2/tokei-api"
    second_repo = "https://github.com/crystal-lang/crystal"

    Tokei::Api::Models::AnalysisFailure.record(first_repo, "clone_failed")
    Tokei::Api::Models::AnalysisFailure.record(first_repo, "clone_failed")
    count, retry_after = Tokei::Api::Models::AnalysisFailure.record(second_repo, "clone_failed")

    count.should eq(1)
    seconds_from_now(retry_after).should be_close(5.minutes.total_seconds, 3.0)
  end

  it "cleans up expired failure rows" do
    conn = Tokei::Api::Config::Database.connection
    begin
      now = Time.utc
      conn.exec(
        "INSERT INTO analysis_failures (repo_url, failure_count, error_type, last_failed_at, retry_after) VALUES (?, ?, ?, ?, ?)",
        "https://github.com/kojix2/tokei-api",
        1,
        "clone_failed",
        Tokei::Api::Models::Analysis.timestamp(now - 10.minutes),
        Tokei::Api::Models::Analysis.timestamp(now - 5.minutes)
      )
    ensure
      conn.close
    end

    Tokei::Api::Models::AnalysisFailure.cleanup_old_data.should eq(1)
    Tokei::Api::Models::AnalysisFailure.suppressed_until("https://github.com/kojix2/tokei-api").should be_nil
  end
end
