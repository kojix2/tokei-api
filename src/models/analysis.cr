require "json"
require "uuid"
require "../config/database"

module Tokei::Api::Models
  # Model class representing repository analysis results
  class Analysis
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

    # Delete analyses older than the retention period (default: 30 days)
    # Can be configured via RETENTION_DAYS environment variable
    def self.cleanup_old_data : Int64
      # Get retention days from environment variable or use default (30 days)
      retention_days = ENV["RETENTION_DAYS"]?.try(&.to_i?) || 30
      
      conn = Tokei::Api::Config::Database.connection
      begin
        result = conn.exec("DELETE FROM analyses WHERE analyzed_at < $1", Time.utc - retention_days.days)
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
          # Create new with statistics
          conn.query(
            "INSERT INTO analyses (repo_url, result, total_lines, total_code, total_comments, total_blanks, top_language, top_language_lines, language_count, code_comment_ratio) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id, analyzed_at",
            @repo_url, @result.to_json, @total_lines, @total_code, @total_comments, @total_blanks, @top_language, @top_language_lines, @language_count, @code_comment_ratio
          ) do |rs|
            if rs.move_next
              @id = rs.read(UUID)
              @analyzed_at = rs.read(Time)
            end
          end
        else
          # Update with statistics
          conn.exec(
            "UPDATE analyses SET repo_url = $1, result = $2, total_lines = $3, total_code = $4, total_comments = $5, total_blanks = $6, top_language = $7, top_language_lines = $8, language_count = $9, code_comment_ratio = $10 WHERE id = $11",
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
        conn.query("SELECT id, repo_url, analyzed_at, result, total_lines, total_code, total_comments, total_blanks, top_language, top_language_lines, language_count, code_comment_ratio FROM analyses WHERE repo_url = $1 ORDER BY analyzed_at DESC", repo_url) do |rs|
          rs.each do
            id_value = rs.read(UUID)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(JSON::Any)

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at

            # Read statistics from database if available
            analysis.total_lines = rs.read(Int32?)
            analysis.total_code = rs.read(Int32?)
            analysis.total_comments = rs.read(Int32?)
            analysis.total_blanks = rs.read(Int32?)
            analysis.top_language = rs.read(String?)
            analysis.top_language_lines = rs.read(Int32?)
            analysis.language_count = rs.read(Int32?)
            analysis.code_comment_ratio = rs.read(Float64?)

            analyses << analysis
          end
        end
        analyses
      ensure
        conn.close
      end
    end

    # Search by ID
    def self.find(id : String) : Analysis?
      conn = Tokei::Api::Config::Database.connection
      begin
        analysis = nil
        conn.query("SELECT id, repo_url, analyzed_at, result, total_lines, total_code, total_comments, total_blanks, top_language, top_language_lines, language_count, code_comment_ratio FROM analyses WHERE id = $1", id) do |rs|
          if rs.move_next
            id_value = rs.read(UUID)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(JSON::Any)

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at

            # Read statistics from database if available
            analysis.total_lines = rs.read(Int32?)
            analysis.total_code = rs.read(Int32?)
            analysis.total_comments = rs.read(Int32?)
            analysis.total_blanks = rs.read(Int32?)
            analysis.top_language = rs.read(String?)
            analysis.top_language_lines = rs.read(Int32?)
            analysis.language_count = rs.read(Int32?)
            analysis.code_comment_ratio = rs.read(Float64?)
          end
        end
        analysis
      ensure
        conn.close
      end
    end
  end
end
