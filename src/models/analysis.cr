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

    def initialize(@repo_url : String, result : String | JSON::Any)
      @id = nil
      @analyzed_at = nil

      # Parse as JSON if string, use as is if JSON::Any
      @result = result.is_a?(String) ? JSON.parse(result) : result
    end

    # Save to database
    def save
      conn = Tokei::Api::Config::Database.connection
      begin
        if id.nil?
          # Create new
          conn.query(
            "INSERT INTO analyses (repo_url, result) VALUES ($1, $2) RETURNING id, analyzed_at",
            @repo_url, @result.to_json
          ) do |rs|
            if rs.move_next
              @id = rs.read(UUID)
              @analyzed_at = rs.read(Time)
            end
          end
        else
          # Update
          conn.exec(
            "UPDATE analyses SET repo_url = $1, result = $2 WHERE id = $3",
            @repo_url, @result.to_json, @id.to_s
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
        conn.query("SELECT id, repo_url, analyzed_at, result FROM analyses WHERE repo_url = $1 ORDER BY analyzed_at DESC", repo_url) do |rs|
          rs.each do
            id_value = rs.read(UUID)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(JSON::Any)

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at
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
        conn.query("SELECT id, repo_url, analyzed_at, result FROM analyses WHERE id = $1", id) do |rs|
          if rs.move_next
            id_value = rs.read(UUID)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(JSON::Any)

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at
          end
        end
        analysis
      ensure
        conn.close
      end
    end
  end
end
