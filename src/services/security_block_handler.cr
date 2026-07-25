require "http/server"
require "uri"

module Tokei::Api::Services
  class SecurityBlockHandler
    include HTTP::Handler

    BLOCKED_ROOT_SEGMENTS = {
      ".aws",
      ".bzr",
      ".docker",
      ".env",
      ".git",
      ".git-credentials",
      ".gitconfig",
      ".hg",
      ".htaccess",
      ".htpasswd",
      ".svn",
      "actuator",
      "adminer",
      "backup",
      "backups",
      "config",
      "db",
      "debug",
      "docker-compose.yml",
      "dump",
      "env",
      "phpinfo",
      "phpmyadmin",
      "private",
      "server-info",
      "server-status",
      "vendor",
      "web.config",
      "wp-admin",
      "wp-content",
      "wp-includes",
      "wp-json",
      "xmlrpc.php",
    }

    BLOCKED_SUBSTRINGS = {
      "/node_modules/",
      "/vendor/phpunit/",
      "/vendor/composer/",
      "/web-inf/",
      "/meta-inf/",
    }

    SCRIPT_EXTENSION_PATTERN    = /\.(?:php\d*|phtml|phar|asp|aspx|ashx|asmx|jsp|jspx|cgi|pl|py|rb|sh|bash)(?:[.\/]|$)/
    SENSITIVE_EXTENSION_PATTERN = /\.(?:bak|backup|old|orig|save|swp|swo|tmp|temp|log|sql|sqlite|db|dump|zip|tar|tgz|gz|rar|7z)(?:$|[\/])/
    ROOT_CONFIG_PATTERN         = /^(?:composer\.(?:json|lock)|package-lock\.json|package\.json|pnpm-lock\.yaml|yarn\.lock|gemfile(?:\.lock)?|shard\.(?:yml|lock)|cargo\.(?:toml|lock)|go\.(?:mod|sum)|requirements\.txt|pipfile(?:\.lock)?|poetry\.lock|pyproject\.toml|webpack\.config\.(?:js|ts)|vite\.config\.(?:js|ts)|tsconfig\.json)$/
    REPOSITORY_ROUTE_PATTERN    = /^\/(?:api\/)?github\/[^\/]+\/[^\/]+(?:\/.*)?$|^\/badge\/github\/[^\/]+\/[^\/]+\/[^\/]+$|^\/og\/github\/[^\/]+\/[^\/]+$/
    MAX_DECODE_PASSES           = 3

    def call(context : HTTP::Server::Context)
      if self.class.blocked_path?(context.request.path)
        context.response.status_code = 404
        context.response.headers["Content-Type"] = "text/plain; charset=utf-8"
        context.response.headers["X-Content-Type-Options"] = "nosniff"
        context.response.print "Not Found" unless context.request.method == "HEAD"
        return context
      end

      call_next(context)
    end

    def self.blocked_path?(path : String) : Bool
      candidates(path).any? { |candidate| blocked_normalized?(candidate) }
    end

    private def self.candidates(path : String) : Array(String)
      current = path.downcase
      results = [current]

      MAX_DECODE_PASSES.times do
        decoded = URI.decode(current).downcase
        break if decoded == current

        results << decoded
        current = decoded
      end

      results
    end

    private def self.blocked_normalized?(normalized_path : String) : Bool
      return false if normalized_path.matches?(REPOSITORY_ROUTE_PATTERN)

      first_segment = normalized_path.split("/", remove_empty: true).first? || ""

      return true if BLOCKED_ROOT_SEGMENTS.includes?(first_segment)
      return true if first_segment.matches?(ROOT_CONFIG_PATTERN)
      return true if BLOCKED_SUBSTRINGS.any? { |needle| normalized_path.includes?(needle) }
      return true if normalized_path.matches?(SCRIPT_EXTENSION_PATTERN)
      return true if normalized_path.matches?(SENSITIVE_EXTENSION_PATTERN)

      false
    end
  end
end
