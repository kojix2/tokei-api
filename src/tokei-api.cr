require "kemal"
require "dotenv"
require "./config/database"
require "./models/analysis"
require "./controllers/api_controller"
require "./controllers/web_controller"
require "./controllers/og_controller"

# tokei-api - API for analyzing Git repository source code with tokei command
module Tokei::Api
  VERSION = "0.1.0"

  # Load environment variables
  Dotenv.load

  # Port configuration
  @@port = ENV["PORT"]?.try(&.to_i) || 3000

  # Database setup
  Config::Database.setup

  # Controller setup
  Controllers::ApiController.setup
  Controllers::WebController.setup
  Controllers::OgController.setup

  # Start application
  def self.start
    puts "Starting tokei-api server..."
    puts "Port: #{@@port}"
    puts "Environment: #{ENV["KEMAL_ENV"]? || "development"}"

    # Cleanup old data on startup
    deleted_count = Models::Analysis.cleanup_old_data
    puts "Cleanup: Removed #{deleted_count} old analysis records"

    Kemal.run(port: @@port)
  end
end
