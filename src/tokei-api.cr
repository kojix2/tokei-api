require "kemal"
require "dotenv"
require "./config/database"
require "./models/analysis"
require "./services/access_log_handler"
require "./services/analysis_service"
require "./controllers/api_controller"
require "./controllers/web_controller"
require "./controllers/og_controller"

# tokei-api - API for analyzing Git repository source code with tokei command
module Tokei::Api
  VERSION = "0.1.0"

  CSP_POLICY = "default-src 'self'; " +
               "base-uri 'self'; " +
               "frame-ancestors 'none'; " +
               "object-src 'none'; " +
               "form-action 'self'; " +
               "script-src 'self' https://cdn.jsdelivr.net; " +
               "style-src 'self' https://cdn.jsdelivr.net; " +
               "img-src 'self' data: https:; " +
               "font-src 'self' https://cdn.jsdelivr.net data:; " +
               "connect-src 'self'"

  # Load environment variables
  Dotenv.load if File.exists?(".env")

  # Port configuration
  @@port = ENV["PORT"]?.try(&.to_i) || 3000

  # Database setup
  Config::Database.setup

  # Controller setup
  Controllers::ApiController.setup
  Controllers::WebController.setup
  Controllers::OgController.setup

  # Structured access logs with request ids shared by route logs.
  logging false
  use Services::AccessLogHandler.new, position: 1

  # Start application
  def self.start
    puts "Starting tokei-api server..."
    puts "Port: #{@@port}"
    puts "Environment: #{ENV["KEMAL_ENV"]? || "development"}"

    # Cleanup old data on startup
    deleted_count = Models::Analysis.cleanup_old_data
    puts "Cleanup: Removed #{deleted_count} old analysis records"

    before_all do |env|
      env.response.headers["Content-Security-Policy"] = ENV["CONTENT_SECURITY_POLICY"]? || CSP_POLICY
      env.response.headers["X-Content-Type-Options"] = "nosniff"
      env.response.headers["Referrer-Policy"] = ENV["REFERRER_POLICY"]? || "strict-origin-when-cross-origin"
      env.response.headers["Permissions-Policy"] = ENV["PERMISSIONS_POLICY"]? || "accelerometer=(), autoplay=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
    end

    Kemal.run(port: @@port)
  end
end
