require "pg"
require "dotenv"

module Tokei::Api::Config
  # Module for managing database connections
  module Database
    # Load environment variables
    Dotenv.load

    # Database provider (local or neon)
    DATABASE_PROVIDER = ENV["DATABASE_PROVIDER"]? || "local"

    # Database connection URL
    DATABASE_URL = ENV["DATABASE_URL"]? || "postgresql://localhost/tokei-api"

    # Get database connection
    def self.connection
      # Set connection options
      conn_options = "#{DATABASE_URL}"

      # Add SSL mode for Neon
      if DATABASE_PROVIDER == "neon" && !conn_options.includes?("sslmode=")
        # Add correctly as URL parameter
        if conn_options.includes?("?")
          conn_options += "&sslmode=require"
        else
          conn_options += "?sslmode=require"
        end
      end

      # Attempt connection
      begin
        PG.connect(conn_options)
      rescue ex
        puts "Database connection error: #{ex.message}"
        puts "Connection target: #{DATABASE_PROVIDER} (#{DATABASE_URL})"
        raise ex
      end
    end

    # Initialize database (create tables, etc.)
    def self.setup
      puts "Initializing database... (Provider: #{DATABASE_PROVIDER})"

      conn = connection
      begin
        # Create analyses table if it doesn't exist (execute SQL commands separately)
        conn.exec "CREATE TABLE IF NOT EXISTS analyses (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          repo_url TEXT NOT NULL,
          analyzed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          result JSONB NOT NULL
        );"

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
