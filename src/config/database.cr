require "db"
require "sqlite3"
require "dotenv"
require "file_utils"
require "../services/log_service"

module Tokei::Api::Config
  # Module for managing database connections
  module Database
    # Load environment variables
    Dotenv.load if File.exists?(".env") && ENV["CRYSTAL_ENV"]? != "test"

    # SQLite cache database path. The default lives under /tmp so the cache is
    # intentionally discarded when the instance is replaced.
    CACHE_DB_PATH = ENV["CACHE_DB_PATH"]? || "/tmp/tokei-api/tokei-api.sqlite3"

    # Get database connection
    def self.connection
      prepare_database_path
      db = DB.open("sqlite3:#{CACHE_DB_PATH}")
      db.exec "PRAGMA busy_timeout = 5000;"
      db
    rescue ex
      Tokei::Api::Services::LogService.error_exception("database.connection.failed", ex, {
        "cache_db_path" => CACHE_DB_PATH,
      })
      raise ex
    end

    private def self.prepare_database_path
      dir = File.dirname(CACHE_DB_PATH)
      FileUtils.mkdir_p(dir) unless dir == "." || Dir.exists?(dir)
    end

    # Initialize database (create tables, etc.)
    def self.setup
      puts "Initializing database..."

      conn = connection
      begin
        conn.exec "PRAGMA journal_mode = WAL;"

        # Create analyses table if it doesn't exist.
        conn.exec <<-SQL
          CREATE TABLE IF NOT EXISTS analyses (
            id TEXT PRIMARY KEY,
            repo_url TEXT NOT NULL,
            analyzed_at TEXT NOT NULL,
            result TEXT NOT NULL,
            total_lines INTEGER,
            total_code INTEGER,
            total_comments INTEGER,
            total_blanks INTEGER,
            top_language TEXT,
            top_language_lines INTEGER,
            language_count INTEGER,
            code_comment_ratio FLOAT
          );
          SQL

        # Create indexes
        conn.exec "CREATE INDEX IF NOT EXISTS idx_analyses_repo_url ON analyses (repo_url);"
        conn.exec "CREATE INDEX IF NOT EXISTS idx_analyses_analyzed_at ON analyses (analyzed_at);"

        puts "Database initialization complete"
      rescue ex
        Tokei::Api::Services::LogService.error_exception("database.setup.failed", ex, {
          "cache_db_path" => CACHE_DB_PATH,
        })
        raise ex
      ensure
        conn.close
      end
    end
  end
end
