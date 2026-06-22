require "./log_service"

module Tokei::Api::Services
  class AccessLogHandler
    include HTTP::Handler

    REQUEST_ID_HEADER = "X-Request-ID"
    REQUEST_ID_KEY    = "request_id"
    REQUEST_ID_SAFE   = /^[A-Za-z0-9_.-]{1,64}$/

    def call(context : HTTP::Server::Context)
      req_id = request_id_for(context)
      context.set(REQUEST_ID_KEY, req_id)
      context.response.headers[REQUEST_ID_HEADER] = req_id

      elapsed = Time.measure { call_next(context) }

      LogService.info("http.request", {
        "req_id"      => req_id,
        "method"      => context.request.method,
        "resource"    => context.request.resource,
        "status"      => context.response.status_code.to_s,
        "duration_ms" => elapsed.total_milliseconds.round(2).to_s,
      })

      context
    end

    private def request_id_for(context : HTTP::Server::Context) : String
      if header = context.request.headers[REQUEST_ID_HEADER]?
        return header if header.matches?(REQUEST_ID_SAFE)
      end

      LogService.request_id
    end
  end
end
