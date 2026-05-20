require "json"
require "uuid"
require "../config/database"

module Tokei::Api::Models
  # Model class representing repository analysis results
  class Analysis
    EMPTY_RESULT_JSON = JSON.parse("{}")

    property id : UUID?
    property repo_url : String
    property analyzed_at : Time?
    property result : JSON::Any

    # Badge statistics properties
    property total_lines : Int32?
    property total_code : Int32?
    property total_comments : Int32?
    property total_blanks : Int32?
    property top_language : String?
    property top_language_lines : Int32?
    property language_count : Int32?
    property code_comment_ratio : Float64?

    def initialize(@repo_url : String, result : String | JSON::Any)
      @id = nil
      @analyzed_at = nil

      # Parse as JSON if string, use as is if JSON::Any
      @result = result.is_a?(String) ? JSON.parse(result) : result

      # Extract statistics from result
      extract_stats_from_result
    end

    ANALYSIS_COLUMNS         = "id, repo_url, analyzed_at, result, total_lines, total_code, total_comments, total_blanks, top_language, top_language_lines, language_count, code_comment_ratio"
    ANALYSIS_SUMMARY_COLUMNS = "id, repo_url, analyzed_at, total_lines, total_code, total_comments, total_blanks, top_language, top_language_lines, language_count, code_comment_ratio"

    def self.timestamp(time : Time) : String
      time.to_rfc3339(fraction_digits: 0)
    end

    private def self.parse_timestamp(value : String) : Time
      Time.parse_rfc3339(value)
    end

    private def self.read_optional_i32(result_set) : Int32?
      result_set.read(Int64?).try(&.to_i32)
    end

    # Delete analyses older than the retention period (default: 7 days)
    # Can be configured via RETENTION_DAYS environment variable
    def self.cleanup_old_data : Int64
      # Get retention days from environment variable or use default (7 days)
      retention_days = ENV["RETENTION_DAYS"]?.try(&.to_i?) || 7

      conn = Tokei::Api::Config::Database.connection
      begin
        result = conn.exec("DELETE FROM analyses WHERE analyzed_at < ?", timestamp(Time.utc - retention_days.days))
        result.rows_affected
      ensure
        conn.close
      end
    end

    # Extract statistics from result JSON for badge generation
    private def extract_stats_from_result
      total_code = 0
      total_comments = 0
      total_blanks = 0
      top_language = ""
      top_language_lines = 0
      language_count = 0

      @result.as_h.each do |language, stats|
        next if language == "Total"
        stats_obj = stats.as_h
        code = stats_obj["code"]?.try(&.as_i) || 0
        comments = stats_obj["comments"]?.try(&.as_i) || 0
        blanks = stats_obj["blanks"]?.try(&.as_i) || 0

        total_code += code
        total_comments += comments
        total_blanks += blanks
        language_count += 1

        if code > top_language_lines
          top_language = language
          top_language_lines = code
        end
      end

      @total_code = total_code
      @total_comments = total_comments
      @total_blanks = total_blanks
      @total_lines = total_code + total_comments + total_blanks
      @top_language = top_language
      @top_language_lines = top_language_lines
      @language_count = language_count
      @code_comment_ratio = total_comments > 0 ? (total_code.to_f / total_comments) : 0.0
    end

    # Save to database
    def save
      conn = Tokei::Api::Config::Database.connection
      begin
        if id.nil?
          now = Time.utc
          @id = UUID.random
          @analyzed_at = now

          # Create new with statistics
          conn.exec(
            "INSERT INTO analyses (id, repo_url, analyzed_at, result, total_lines, total_code, total_comments, total_blanks, top_language, top_language_lines, language_count, code_comment_ratio) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            @id.to_s, @repo_url, self.class.timestamp(now), @result.to_json, @total_lines, @total_code, @total_comments, @total_blanks, @top_language, @top_language_lines, @language_count, @code_comment_ratio
          )
        else
          # Update with statistics
          conn.exec(
            "UPDATE analyses SET repo_url = ?, result = ?, total_lines = ?, total_code = ?, total_comments = ?, total_blanks = ?, top_language = ?, top_language_lines = ?, language_count = ?, code_comment_ratio = ? WHERE id = ?",
            @repo_url, @result.to_json, @total_lines, @total_code, @total_comments, @total_blanks, @top_language, @top_language_lines, @language_count, @code_comment_ratio, @id.to_s
          )
        end
        true
      rescue ex
        puts "Error saving analysis: #{ex.message}"
        false
      ensure
        conn.close
      end
    end

    # Search by repository URL
    def self.find_by_repo_url(repo_url : String) : Array(Analysis)
      conn = Tokei::Api::Config::Database.connection
      begin
        analyses = [] of Analysis
        conn.query("SELECT #{ANALYSIS_COLUMNS} FROM analyses WHERE repo_url = ? ORDER BY analyzed_at DESC", repo_url) do |result_set|
          result_set.each do
            id_value = UUID.new(result_set.read(String))
            repo_url = result_set.read(String)
            analyzed_at = parse_timestamp(result_set.read(String))
            result = JSON.parse(result_set.read(String))

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at

            # Read statistics from database if available
            analysis.total_lines = read_optional_i32(result_set)
            analysis.total_code = read_optional_i32(result_set)
            analysis.total_comments = read_optional_i32(result_set)
            analysis.total_blanks = read_optional_i32(result_set)
            analysis.top_language = result_set.read(String?)
            analysis.top_language_lines = read_optional_i32(result_set)
            analysis.language_count = read_optional_i32(result_set)
            analysis.code_comment_ratio = result_set.read(Float64?)

            analyses << analysis
          end
        end
        analyses
      ensure
        conn.close
      end
    end

    # Search latest analysis by repository URL without loading large result JSON.
    # Useful for summary/badge flows where only precomputed stats are needed.
    def self.find_latest_by_repo_url(repo_url : String) : Analysis?
      conn = Tokei::Api::Config::Database.connection
      begin
        analysis = nil
        conn.query("SELECT #{ANALYSIS_SUMMARY_COLUMNS} FROM analyses WHERE repo_url = ? ORDER BY analyzed_at DESC LIMIT 1", repo_url) do |result_set|
          if result_set.move_next
            id_value = UUID.new(result_set.read(String))
            repo_url = result_set.read(String)
            analyzed_at = parse_timestamp(result_set.read(String))

            record = Analysis.new(repo_url, EMPTY_RESULT_JSON)
            record.id = id_value
            record.analyzed_at = analyzed_at
            record.total_lines = read_optional_i32(result_set)
            record.total_code = read_optional_i32(result_set)
            record.total_comments = read_optional_i32(result_set)
            record.total_blanks = read_optional_i32(result_set)
            record.top_language = result_set.read(String?)
            record.top_language_lines = read_optional_i32(result_set)
            record.language_count = read_optional_i32(result_set)
            record.code_comment_ratio = result_set.read(Float64?)
            analysis = record
          end
        end
        analysis
      ensure
        conn.close
      end
    end

    # Search latest analysis by repository URL with the full result JSON.
    # Useful for flows that need language breakdown data.
    def self.find_latest_full_by_repo_url(repo_url : String) : Analysis?
      conn = Tokei::Api::Config::Database.connection
      begin
        analysis = nil
        conn.query("SELECT #{ANALYSIS_COLUMNS} FROM analyses WHERE repo_url = ? ORDER BY analyzed_at DESC LIMIT 1", repo_url) do |result_set|
          if result_set.move_next
            id_value = UUID.new(result_set.read(String))
            repo_url = result_set.read(String)
            analyzed_at = parse_timestamp(result_set.read(String))
            result = JSON.parse(result_set.read(String))

            record = Analysis.new(repo_url, result)
            record.id = id_value
            record.analyzed_at = analyzed_at
            record.total_lines = read_optional_i32(result_set)
            record.total_code = read_optional_i32(result_set)
            record.total_comments = read_optional_i32(result_set)
            record.total_blanks = read_optional_i32(result_set)
            record.top_language = result_set.read(String?)
            record.top_language_lines = read_optional_i32(result_set)
            record.language_count = read_optional_i32(result_set)
            record.code_comment_ratio = result_set.read(Float64?)
            analysis = record
          end
        end
        analysis
      ensure
        conn.close
      end
    end

    # Search by ID without loading large result JSON.
    # Useful for badge endpoint where only stats are required.
    def self.find_summary_by_id(id : String) : Analysis?
      conn = Tokei::Api::Config::Database.connection
      begin
        analysis = nil
        conn.query("SELECT #{ANALYSIS_SUMMARY_COLUMNS} FROM analyses WHERE id = ?", id) do |result_set|
          if result_set.move_next
            id_value = UUID.new(result_set.read(String))
            repo_url = result_set.read(String)
            analyzed_at = parse_timestamp(result_set.read(String))

            record = Analysis.new(repo_url, EMPTY_RESULT_JSON)
            record.id = id_value
            record.analyzed_at = analyzed_at
            record.total_lines = read_optional_i32(result_set)
            record.total_code = read_optional_i32(result_set)
            record.total_comments = read_optional_i32(result_set)
            record.total_blanks = read_optional_i32(result_set)
            record.top_language = result_set.read(String?)
            record.top_language_lines = read_optional_i32(result_set)
            record.language_count = read_optional_i32(result_set)
            record.code_comment_ratio = result_set.read(Float64?)
            analysis = record
          end
        end
        analysis
      ensure
        conn.close
      end
    end

    # Search by ID
    def self.find(id : String) : Analysis?
      conn = Tokei::Api::Config::Database.connection
      begin
        analysis = nil
        conn.query("SELECT #{ANALYSIS_COLUMNS} FROM analyses WHERE id = ?", id) do |result_set|
          if result_set.move_next
            id_value = UUID.new(result_set.read(String))
            repo_url = result_set.read(String)
            analyzed_at = parse_timestamp(result_set.read(String))
            result = JSON.parse(result_set.read(String))

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at

            # Read statistics from database if available
            analysis.total_lines = read_optional_i32(result_set)
            analysis.total_code = read_optional_i32(result_set)
            analysis.total_comments = read_optional_i32(result_set)
            analysis.total_blanks = read_optional_i32(result_set)
            analysis.top_language = result_set.read(String?)
            analysis.top_language_lines = read_optional_i32(result_set)
            analysis.language_count = read_optional_i32(result_set)
            analysis.code_comment_ratio = result_set.read(Float64?)
          end
        end
        analysis
      ensure
        conn.close
      end
    end
  end
end
