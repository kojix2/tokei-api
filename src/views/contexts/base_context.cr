require "socket"

module Tokei::Api::Views::Contexts
  # Base context class
  abstract class BaseContext
    property error_message : String?

    def initialize(@error_message = nil)
    end

    # Get server hostname or IP address
    def server_host : String
      # Get host from environment variable (if set)
      env_host = ENV["HOST"]?
      return env_host if env_host && !env_host.empty?

      # Execute `hostname -I` command to get IP address
      begin
        ip_address = `hostname -I`.strip.split.first
        return ip_address unless ip_address.empty?
      rescue
        # Return localhost if an error occurs
      end

      # Default is localhost
      "localhost"
    end

    # Get server port number
    def server_port : Int32
      ENV["PORT"]?.try(&.to_i) || 3000
    end

    # Get server base URL
    def server_base_url : String
      ENV["BASE_URL"]? || "http://#{server_host}:#{server_port}"
    end
  end
end
