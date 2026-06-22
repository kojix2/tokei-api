require "random"

module Tokei::Api::Services
  # Small structured logger for operational diagnostics.
  module LogService
    MAX_VALUE_LENGTH = 500

    def self.request_id : String
      Random::Secure.hex(4)
    end

    def self.info(event : String, fields = {} of String => String) : Nil
      log("INFO", event, stringify_fields(fields))
    end

    def self.warn(event : String, fields = {} of String => String) : Nil
      log("WARN", event, stringify_fields(fields))
    end

    def self.error(event : String, fields = {} of String => String) : Nil
      log("ERROR", event, stringify_fields(fields))
    end

    def self.error_exception(event : String, ex : Exception, fields = {} of String => String) : Nil
      error(event, stringify_fields(fields).merge(exception_fields(ex)))
    end

    def self.mask_url(url : String) : String
      url.gsub(%r{//[^/\s@]+@}, "//[redacted]@")
    end

    def self.exception_fields(ex : Exception) : Hash(String, String)
      class_name = ex.class.name || ex.class.to_s
      message = mask_url(ex.message || "")

      {
        "error_class"   => class_name,
        "error_message" => message,
      }
    end

    private def self.stringify_fields(fields) : Hash(String, String)
      string_fields = {} of String => String
      fields.each do |key, value|
        string_fields[key] = value.to_s
      end
      string_fields
    end

    private def self.log(level : String, event : String, fields : Hash(String, String)) : Nil
      STDERR.puts String.build { |io|
        io << Time.utc.to_rfc3339 << " " << level << " event=" << sanitize(event).inspect
        fields.each do |key, value|
          io << " " << sanitize_key(key) << "=" << sanitize(value).inspect
        end
      }
    end

    private def self.sanitize_key(key : String) : String
      key.gsub(/[^A-Za-z0-9_.-]/, "_")
    end

    private def self.sanitize(value : String) : String
      normalized = value.gsub(/\s+/, " ").strip
      return normalized if normalized.size <= MAX_VALUE_LENGTH

      "#{normalized[0, MAX_VALUE_LENGTH]}..."
    end
  end
end
