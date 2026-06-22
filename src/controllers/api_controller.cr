require "kemal"
require "json"
require "../services/tokei_service"
require "../services/language_stats_service"
require "../services/badge_service"
require "../services/log_service"
require "../models/analysis"

module Tokei::Api::Controllers
  # Controller for API
  module ApiController
    GITHUB_PATH_SAFE = /^[A-Za-z0-9._-]+$/

    private def self.valid_github_param?(value : String) : Bool
      value.matches?(GITHUB_PATH_SAFE)
    end

    private def self.invalid_owner_repo_response(env : HTTP::Server::Context) : String
      env.response.status_code = 400
      env.response.content_type = "application/json"
      {error: {code: "invalid_request", message: "Invalid owner or repo", status: 400}}.to_json
    end

    private def self.status_for_exception(ex : Exception) : Int32
      case ex
      when Tokei::Api::Services::TokeiService::CloneTimeoutError,
           Tokei::Api::Services::TokeiService::AnalysisTimeoutError
        504
      when Tokei::Api::Services::TokeiService::CloneFailedError,
           Tokei::Api::Services::TokeiService::AnalysisFailedError
        502
      else
        500
      end
    end

    private def self.log_route_error(event : String, ex : Exception, fields = {} of String => String) : Nil
      Tokei::Api::Services::LogService.error_exception(event, ex, fields)
    end

    private def self.mask_repo_url(repo_url : String) : String
      Tokei::Api::Services::LogService.mask_url(repo_url)
    end

    private def self.request_id : String
      Tokei::Api::Services::LogService.request_id
    end

    # Badge data generation (via shared service)
    private def self.generate_badge_data(badge_type : String, analysis)
      Tokei::Api::Services::BadgeService.generate(badge_type, analysis)
    end

    # Get the most recent analysis for a repository URL
    private def self.get_analysis_for_repo(repo_url : String, req_id : String = request_id)
      # URL validation
      unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
        raise "Invalid repository URL"
      end

      # Search latest analysis result using lightweight summary query
      recent_analysis = Tokei::Api::Models::Analysis.find_latest_by_repo_url(repo_url)

      # Check if we have any recent analysis results (within 24 hours)
      if recent_analysis && recent_analysis.analyzed_at.try(&.> Time.utc - 24.hours)
        return recent_analysis
      end

      # Analyze repository
      result = Tokei::Api::Services::TokeiService.analyze_repo(repo_url, req_id)

      # Save to database
      analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
      saved = analysis.save
      raise "Failed to persist analysis result" unless saved && analysis.id

      analysis
    end

    # Get analysis with full result payload when language breakdown is needed.
    private def self.get_full_analysis_for_repo(repo_url : String, req_id : String = request_id)
      analysis = get_analysis_for_repo(repo_url, req_id)

      # Summary-only records carry an empty result payload; reload full row by id.
      unless analysis.result.as_h.empty?
        return analysis
      end

      id = analysis.id
      if id && (full_analysis = Tokei::Api::Models::Analysis.find(id.to_s))
        return full_analysis
      end

      # Fallback: perform analysis again if the row disappeared between queries.
      result = Tokei::Api::Services::TokeiService.analyze_repo(repo_url, req_id)
      refreshed = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
      saved = refreshed.save
      raise "Failed to persist analysis result" unless saved && refreshed.id
      refreshed
    end

    # Setup API endpoints
    # ameba:disable Metrics/CyclomaticComplexity
    def self.setup
      # GET /api/badge/:type endpoint (for dynamic shields.io badges)
      get "/api/badge/:type" do |env|
        req_id = request_id
        begin
          # Get badge type and repository URL
          badge_type = env.params.url["type"]
          # NOTE: query param may be missing
          repo_url = env.params.query["url"]? || ""

          env.response.content_type = "application/json"

          # URL validation
          unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
            env.response.status_code = 400
            next {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid repository URL",
              color:         "red",
            }.to_json
          end

          # Search for existing analysis results (badge endpoint does not trigger analysis)
          analysis = Tokei::Api::Models::Analysis.find_latest_by_repo_url(repo_url)

          # Check if we have any analysis result
          if analysis.nil?
            env.response.status_code = 404
            next {
              schemaVersion: 1,
              label:         "error",
              message:       "No analysis found",
              color:         "red",
            }.to_json
          end

          # Allow intermediaries to cache badge payload briefly
          env.response.headers["Cache-Control"] = "public, max-age=300"

          # Generate badge data
          begin
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.badge.failed", ex, {
            "req_id"     => req_id,
            "route"      => "/api/badge/:type",
            "badge_type" => badge_type,
            "repo_url"   => mask_repo_url(repo_url.to_s),
            "status"     => env.response.status_code.to_s,
          })
          {
            schemaVersion: 1,
            label:         "error",
            message:       "Server error",
            color:         "red",
          }.to_json
        end
      end

      # Core API endpoints

      # POST /api/analyses endpoint (analyze a repository)
      post "/api/analyses" do |env|
        req_id = request_id
        begin
          # Get repository URL from request body
          request_body = env.request.body.try(&.gets_to_end) || ""
          if request_body.empty?
            raise KeyError.new("Missing required field: url")
          end
          request_json = JSON.parse(request_body)

          repo_url = request_json["url"]?.try(&.as_s) || ""

          if repo_url.empty?
            raise KeyError.new("Missing required field: url")
          end

          # Get analysis
          analysis = get_analysis_for_repo(repo_url, req_id)

          # Prepare response data
          response_data = {
            data: {
              id:          analysis.id.to_s,
              url:         analysis.repo_url,
              analyzed_at: analysis.analyzed_at,
              status:      "completed",
              summary:     {
                total_lines:        analysis.total_lines,
                total_code:         analysis.total_code,
                total_comments:     analysis.total_comments,
                total_blanks:       analysis.total_blanks,
                languages_count:    analysis.language_count,
                top_language:       analysis.top_language,
                code_comment_ratio: analysis.code_comment_ratio,
              },
              links: {
                self:      "/api/analyses/#{analysis.id}",
                languages: "/api/analyses/#{analysis.id}/languages",
                web:       "/analyses/#{analysis.id}",
              },
            },
          }

          # Return results
          env.response.status_code = 201 # Created
          env.response.content_type = "application/json"
          response_data.to_json
        rescue JSON::ParseException
          env.response.status_code = 400
          {error: {code: "invalid_request", message: "Invalid JSON format", status: 400}}.to_json
        rescue KeyError
          env.response.status_code = 400
          {error: {code: "invalid_request", message: "Missing required field: url", status: 400}}.to_json
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.analysis.create.failed", ex, {
            "req_id"   => req_id,
            "route"    => "POST /api/analyses",
            "repo_url" => mask_repo_url(repo_url.to_s),
            "status"   => env.response.status_code.to_s,
          })
          {error: {code: "server_error", message: "Internal server error", status: env.response.status_code}}.to_json
        end
      end

      # GET /api/analyses endpoint (retrieve analysis result by repository URL)
      get "/api/analyses" do |env|
        req_id = request_id
        begin
          # Get repository URL from query parameter
          repo_url = env.params.query["url"]

          # Return error if URL is not provided
          if repo_url.nil? || repo_url.empty?
            env.response.status_code = 400
            next {error: {code: "invalid_request", message: "Missing required query parameter: url", status: 400}}.to_json
          end

          # Validate repository URL
          unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
            env.response.status_code = 400
            next {error: {code: "invalid_request", message: "Invalid repository URL", status: 400}}.to_json
          end

          # Find latest analysis result for the repository
          analysis = Tokei::Api::Models::Analysis.find_latest_by_repo_url(repo_url)

          # Return 404 if no analysis is found
          if analysis.nil?
            env.response.status_code = 404
            next {error: {code: "not_found", message: "No analysis found for the given URL", status: 404}}.to_json
          end

          # Prepare response data
          response_data = {
            data: {
              id:          analysis.id.to_s,
              url:         analysis.repo_url,
              analyzed_at: analysis.analyzed_at,
              status:      "completed",
              summary:     {
                total_lines:        analysis.total_lines,
                total_code:         analysis.total_code,
                total_comments:     analysis.total_comments,
                total_blanks:       analysis.total_blanks,
                languages_count:    analysis.language_count,
                top_language:       analysis.top_language,
                code_comment_ratio: analysis.code_comment_ratio,
              },
              links: {
                self:      "/api/analyses/#{analysis.id}",
                languages: "/api/analyses/#{analysis.id}/languages",
                web:       "/analyses/#{analysis.id}",
              },
            },
          }

          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.analysis.lookup.failed", ex, {
            "req_id"   => req_id,
            "route"    => "GET /api/analyses",
            "repo_url" => mask_repo_url(repo_url.to_s),
            "status"   => env.response.status_code.to_s,
          })
          {error: {code: "server_error", message: "Internal server error", status: env.response.status_code}}.to_json
        end
      end

      # GET /api/analyses/:id endpoint (retrieve specific analysis results)
      get "/api/analyses/:id" do |env|
        req_id = request_id
        begin
          id = env.params.url["id"]

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            next {error: {code: "not_found", message: "Analysis not found", status: 404}}.to_json
          end

          languages_data = Tokei::Api::Services::LanguageStatsService.extract_basic(analysis.result)

          # Prepare response data
          response_data = {
            data: {
              id:          analysis.id.to_s,
              url:         analysis.repo_url,
              analyzed_at: analysis.analyzed_at,
              status:      "completed",
              summary:     {
                total_lines:        analysis.total_lines,
                total_code:         analysis.total_code,
                total_comments:     analysis.total_comments,
                total_blanks:       analysis.total_blanks,
                languages_count:    analysis.language_count,
                top_language:       analysis.top_language,
                code_comment_ratio: analysis.code_comment_ratio,
              },
              languages: languages_data,
              links:     {
                self:      "/api/analyses/#{analysis.id}",
                languages: "/api/analyses/#{analysis.id}/languages",
                web:       "/analyses/#{analysis.id}",
              },
            },
          }

          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.analysis.show.failed", ex, {
            "req_id" => req_id,
            "route"  => "GET /api/analyses/:id",
            "id"     => id,
            "status" => env.response.status_code.to_s,
          })
          {error: {code: "server_error", message: "Internal server error", status: env.response.status_code}}.to_json
        end
      end

      # GET /api/analyses/:id/languages endpoint (retrieve language statistics)
      get "/api/analyses/:id/languages" do |env|
        req_id = request_id
        begin
          id = env.params.url["id"]

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            next {error: {code: "not_found", message: "Analysis not found", status: 404}}.to_json
          end

          languages_data = Tokei::Api::Services::LanguageStatsService.extract_with_percentage(analysis.result)

          # Prepare response data
          response_data = {
            data: {
              repository_id: analysis.id.to_s,
              languages:     languages_data,
            },
          }

          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.analysis.languages.failed", ex, {
            "req_id" => req_id,
            "route"  => "GET /api/analyses/:id/languages",
            "id"     => id,
            "status" => env.response.status_code.to_s,
          })
          {error: {code: "server_error", message: "Internal server error", status: env.response.status_code}}.to_json
        end
      end

      # GET /api/analyses/:id/badges/:type endpoint (retrieve badge data)
      get "/api/analyses/:id/badges/:type" do |env|
        req_id = request_id
        begin
          id = env.params.url["id"]
          badge_type = env.params.url["type"]

          env.response.content_type = "application/json"

          analysis = Tokei::Api::Models::Analysis.find_summary_by_id(id)

          if analysis.nil?
            env.response.status_code = 404
            next {
              schemaVersion: 1,
              label:         "error",
              message:       "Analysis not found",
              color:         "red",
            }.to_json
          end

          env.response.headers["Cache-Control"] = "public, max-age=300"

          # Generate badge data
          begin
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.analysis.badge.failed", ex, {
            "req_id"     => req_id,
            "route"      => "/api/analyses/:id/badges/:type",
            "id"         => id,
            "badge_type" => badge_type,
            "status"     => env.response.status_code.to_s,
          })
          {
            schemaVersion: 1,
            label:         "error",
            message:       "Server error",
            color:         "red",
          }.to_json
        end
      end

      # GitHub-specific API endpoints

      # GET /api/github/:owner/:repo endpoint (analyze GitHub repository)
      get "/api/github/:owner/:repo" do |env|
        req_id = request_id
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]

          unless valid_github_param?(owner) && valid_github_param?(repo)
            next invalid_owner_repo_response(env)
          end

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_full_analysis_for_repo(repo_url, req_id)

          languages_data = Tokei::Api::Services::LanguageStatsService.extract_basic(analysis.result)

          # Prepare response data
          response_data = {
            data: {
              id:          analysis.id.to_s,
              url:         analysis.repo_url,
              owner:       owner,
              repo:        repo,
              analyzed_at: analysis.analyzed_at,
              status:      "completed",
              summary:     {
                total_lines:        analysis.total_lines,
                total_code:         analysis.total_code,
                total_comments:     analysis.total_comments,
                total_blanks:       analysis.total_blanks,
                languages_count:    analysis.language_count,
                top_language:       analysis.top_language,
                code_comment_ratio: analysis.code_comment_ratio,
              },
              languages: languages_data,
              links:     {
                self:      "/api/github/#{owner}/#{repo}",
                languages: "/api/github/#{owner}/#{repo}/languages",
                web:       "/github/#{owner}/#{repo}",
                badges:    {
                  lines:     "/api/github/#{owner}/#{repo}/badges/lines",
                  language:  "/api/github/#{owner}/#{repo}/badges/language",
                  languages: "/api/github/#{owner}/#{repo}/badges/languages",
                  ratio:     "/api/github/#{owner}/#{repo}/badges/ratio",
                },
              },
            },
          }

          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.github.show.failed", ex, {
            "req_id"   => req_id,
            "route"    => "GET /api/github/:owner/:repo",
            "owner"    => owner,
            "repo"     => repo,
            "repo_url" => mask_repo_url("https://github.com/#{owner}/#{repo}"),
            "status"   => env.response.status_code.to_s,
          })
          {error: {code: "server_error", message: "Internal server error", status: env.response.status_code}}.to_json
        end
      end

      # GET /api/github/:owner/:repo/languages endpoint (retrieve language statistics)
      get "/api/github/:owner/:repo/languages" do |env|
        req_id = request_id
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]

          unless valid_github_param?(owner) && valid_github_param?(repo)
            next invalid_owner_repo_response(env)
          end

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_full_analysis_for_repo(repo_url, req_id)

          languages_data = Tokei::Api::Services::LanguageStatsService.extract_with_percentage(analysis.result)

          # Prepare response data
          response_data = {
            data: {
              owner:         owner,
              repo:          repo,
              repository_id: analysis.id.to_s,
              languages:     languages_data,
            },
          }

          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.github.languages.failed", ex, {
            "req_id"   => req_id,
            "route"    => "GET /api/github/:owner/:repo/languages",
            "owner"    => owner,
            "repo"     => repo,
            "repo_url" => mask_repo_url("https://github.com/#{owner}/#{repo}"),
            "status"   => env.response.status_code.to_s,
          })
          {error: {code: "server_error", message: "Internal server error", status: env.response.status_code}}.to_json
        end
      end

      # GET /api/github/:owner/:repo/badges/:type endpoint (retrieve badge data)
      get "/api/github/:owner/:repo/badges/:type" do |env|
        req_id = request_id
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]
          badge_type = env.params.url["type"]

          unless valid_github_param?(owner) && valid_github_param?(repo)
            next invalid_owner_repo_response(env)
          end

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_analysis_for_repo(repo_url, req_id)

          # Generate badge data
          begin
            env.response.content_type = "application/json"
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("api.github.badge.failed", ex, {
            "req_id"     => req_id,
            "route"      => "/api/github/:owner/:repo/badges/:type",
            "owner"      => owner,
            "repo"       => repo,
            "repo_url"   => mask_repo_url("https://github.com/#{owner}/#{repo}"),
            "badge_type" => badge_type,
            "status"     => env.response.status_code.to_s,
          })
          {
            schemaVersion: 1,
            label:         "error",
            message:       "Server error",
            color:         "red",
          }.to_json
        end
      end

      # Badge direct access endpoint

      # GET /badge/github/:owner/:repo/:type endpoint (simplified badge URLs)
      get "/badge/github/:owner/:repo/:type" do |env|
        req_id = request_id
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]
          badge_type = env.params.url["type"]

          unless valid_github_param?(owner) && valid_github_param?(repo)
            next invalid_owner_repo_response(env)
          end

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_analysis_for_repo(repo_url, req_id)

          # Generate badge data
          begin
            env.response.content_type = "application/json"
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = status_for_exception(ex)
          log_route_error("badge.github.failed", ex, {
            "req_id"     => req_id,
            "route"      => "/badge/github/:owner/:repo/:type",
            "owner"      => owner,
            "repo"       => repo,
            "repo_url"   => mask_repo_url("https://github.com/#{owner}/#{repo}"),
            "badge_type" => badge_type,
            "status"     => env.response.status_code.to_s,
          })
          {
            schemaVersion: 1,
            label:         "error",
            message:       "Server error",
            color:         "red",
          }.to_json
        end
      end
      # ameba:enable Metrics/CyclomaticComplexity
    end
  end
end
