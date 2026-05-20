module Tokei::Api::Views::Contexts
  # Base context class
  abstract class BaseContext
    property error_message : String?

    def initialize(@error_message = nil)
    end

    # Get server port number
    def server_port : Int32
      ENV["PORT"]?.try(&.to_i) || 3000
    end

    # Get server base URL from trusted configuration only.
    def server_base_url : String
      ENV["BASE_URL"]? || "http://localhost:#{server_port}"
    end
  end
end
