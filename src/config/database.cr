require "pg"
require "dotenv"

module Tokei::Api::Config
  # Module for managing database connections
  module Database
    # Load environment variables
    Dotenv.load if File.exists?(".env") && ENV["CRYSTAL_ENV"]? != "test"

    # Database connection URL
    DATABASE_URL = ENV["DATABASE_URL"]? || "postgresql://localhost/tokei-api"

    # Get database connection
    def self.connection
      # Attempt connection
      begin
        PG.connect(DATABASE_URL)
      rescue ex
        puts "Database connection error: #{ex.message}"
        raise ex
      end
    end

    # Initialize database (create tables, etc.)
    def self.setup
      puts "Initializing database..."

      conn = connection
      begin
        # Create analyses table if it doesn't exist (execute SQL commands separately)
        conn.exec <<-SQL
          CREATE TABLE IF NOT EXISTS analyses (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            repo_url TEXT NOT NULL,
            analyzed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            result JSONB NOT NULL,
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
        puts "Database initialization error: #{ex.message}"
        raise ex
      ensure
        conn.close
      end
    end
  end
end
