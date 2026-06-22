require "kemal"
require "../services/tokei_service"
require "../services/log_service"
require "../models/analysis"
require "../views/renderer"
require "../views/contexts/layout_context"

module Tokei::Api::Controllers
  # Controller for Web
  module WebController
    GITHUB_PATH_SAFE = /^[A-Za-z0-9._-]+$/

    private def self.valid_github_param?(value : String) : Bool
      value.matches?(GITHUB_PATH_SAFE)
    end

    private def self.request_id : String
      Tokei::Api::Services::LogService.request_id
    end

    private def self.log_web_error(event : String, ex : Exception, fields = {} of String => String) : Nil
      Tokei::Api::Services::LogService.error_exception(event, ex, fields)
    end

    # Detect common social preview bots (Twitter, Facebook, LinkedIn, Slack, Discord, etc.)
    private def self.social_bot?(ua : String?) : Bool
      return false unless ua
      !!(ua =~ /Twitterbot|facebookexternalhit|LinkedInBot|Slackbot|Discordbot|WhatsApp|TelegramBot|Mastodon|Line|iMessage/i)
    end

    # Build absolute base URL from trusted configuration only.
    private def self.base_url : String
      ENV["BASE_URL"]? || "http://localhost:#{ENV["PORT"]?.try(&.to_i) || 3000}"
    end

    # Process analyze request (common logic for GET and POST)
    private def self.process_analyze_request(env, repo_url, req_id : String = request_id)
      # URL validation
      unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
        env.response.status_code = 400
        error_message = "Invalid repository URL"
        return Tokei::Api::Views::Renderer.render_index(error_message)
      end

      # Search latest analysis result using lightweight summary query
      recent_analysis = Tokei::Api::Models::Analysis.find_latest_by_repo_url(repo_url)

      if recent_analysis && recent_analysis.analyzed_at.try(&.> Time.utc - 24.hours)
        # Use recent analysis results if available
        analysis = recent_analysis
      else
        # Analyze repository
        result = Tokei::Api::Services::TokeiService.analyze_repo(repo_url, req_id)

        # Save to database
        analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
        saved = analysis.save
        raise "Failed to persist analysis result" unless saved && analysis.id
      end

      # Redirect to results page
      env.redirect "/analyses/#{analysis.id}"
    rescue ex
      log_web_error("web.analyze.failed", ex, {
        "req_id"   => req_id,
        "route"    => "/analyze",
        "repo_url" => Tokei::Api::Services::LogService.mask_url(repo_url.to_s),
      })
      error_message = "An internal error occurred"
      Tokei::Api::Views::Renderer.render_index(error_message)
    end

    # Process GitHub repository analyze request
    private def self.process_github_analyze_request(env, owner, repo, req_id : String = request_id)
      # Construct GitHub repository URL
      repo_url = "https://github.com/#{owner}/#{repo}"

      # Use the common analyze request processing
      process_analyze_request(env, repo_url, req_id)
    end

    # Setup Web endpoints
    def self.setup
      # GET / endpoint (home page)
      get "/" do |_env|
        error_message = nil
        Tokei::Api::Views::Renderer.render_index(error_message)
      end

      # GET /analyze endpoint (for badge links) - redirect to /analyses
      get "/analyze" do |env|
        req_id = request_id
        # Get repository URL from query parameters
        repo_url = env.params.query["url"]
        process_analyze_request(env, repo_url, req_id)
      end

      # POST /analyze endpoint (form submission) - redirect to /analyses
      post "/analyze" do |env|
        req_id = request_id
        # Get repository URL from form
        repo_url = env.params.body["url"]
        process_analyze_request(env, repo_url, req_id)
      end

      # POST /analyses endpoint (form submission - new API structure)
      post "/analyses" do |env|
        req_id = request_id
        # Get repository URL from form
        repo_url = env.params.body["url"]
        process_analyze_request(env, repo_url, req_id)
      end

      # GET /result/:id endpoint (results display page) - redirect to /analyses/:id
      get "/result/:id" do |env|
        id = env.params.url["id"]
        env.redirect "/analyses/#{id}"
      end

      # GET /analyses/:id endpoint (results display page - new API structure)
      get "/analyses/:id" do |env|
        req_id = request_id
        begin
          id = env.params.url["id"]

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            error_message = "Analysis not found"
            next Tokei::Api::Views::Renderer.render_index(error_message)
          end

          # Analysis results are already JSON::Any
          result_json = analysis.result

          Tokei::Api::Views::Renderer.render_result(analysis, result_json)
        rescue ex
          env.response.status_code = 500
          log_web_error("web.analysis.show.failed", ex, {
            "req_id" => req_id,
            "route"  => "/analyses/:id",
            "id"     => id,
          })
          error_message = "An internal error occurred"
          Tokei::Api::Views::Renderer.render_index(error_message)
        end
      end

      # GET /repos/:id endpoint (results display page - redirect to /analyses/:id)
      get "/repos/:id" do |env|
        id = env.params.url["id"]
        env.redirect "/analyses/#{id}"
      end

      # GET /analyses endpoint (analysis list/search page)
      get "/analyses" do |env|
        # This could be implemented in the future to show a list of recently analyzed repositories
        # For now, redirect to home page
        env.redirect "/"
      end

      # GET /github/:owner/:repo endpoint
      # - Social bots: return minimal HTML with OG tags (no redirect)
      # - Humans: run analysis then redirect to /analyses/:id
      get "/github/:owner/:repo" do |env|
        req_id = request_id
        owner = env.params.url["owner"]
        repo = env.params.url["repo"]

        unless valid_github_param?(owner) && valid_github_param?(repo)
          env.response.status_code = 400
          next Tokei::Api::Views::Renderer.render_index("Invalid GitHub owner or repository")
        end

        if social_bot?(env.request.headers["User-Agent"]?)
          base = base_url
          safe_owner = HTML.escape(owner)
          safe_repo = HTML.escape(repo)
          image = "#{base}/og/github/#{owner}/#{repo}?format=png"

          meta = String.build do |io|
            io << %(<meta property="og:type" content="website">)
            io << %(<meta property="og:title" content="#{safe_owner}/#{safe_repo}">)
            io << %(<meta property="og:description" content="Language breakdown by tokei">)
            io << %(<meta property="og:url" content="#{base}/github/#{owner}/#{repo}">)
            io << %(<meta property="og:image" content="#{image}">)
            io << %(<meta property="og:image:width" content="1200">)
            io << %(<meta property="og:image:height" content="630">)
            io << %(<meta name="twitter:card" content="summary_large_image">)
          end

          body = String.build do |io|
            io << %(<h1>#{safe_owner}/#{safe_repo}</h1>)
            io << %(<p>Share this URL on social networks to show a bar chart preview.</p>)
            io << %(<img src="#{image}" alt="OG Preview" width="600" height="315">)
          end

          html = Tokei::Api::Views::Contexts::LayoutContext.new(body, nil, meta).to_s
          env.response.content_type = "text/html; charset=utf-8"
          next html
        end

        # Fallback for regular browsers: perform analysis and redirect
        begin
          process_github_analyze_request(env, owner, repo, req_id)
        rescue ex
          env.response.status_code = 500
          log_web_error("web.github.show.failed", ex, {
            "req_id"   => req_id,
            "route"    => "/github/:owner/:repo",
            "owner"    => owner,
            "repo"     => repo,
            "repo_url" => "https://github.com/#{owner}/#{repo}",
          })
          error_message = "An internal error occurred"
          Tokei::Api::Views::Renderer.render_index(error_message)
        end
      end

      # POST /cleanup endpoint (delete old data)
      # Disabled from public routes.
      # post "/cleanup" do |env|
      #   begin
      #     deleted_count = Tokei::Api::Models::Analysis.cleanup_old_data
      #     env.response.status_code = 200
      #     env.response.print "Deleted #{deleted_count} old records."
      #   rescue ex
      #     env.response.status_code = 500
      #     STDERR.puts "cleanup error: #{ex.message}"
      #     env.response.print "An internal error occurred"
      #   end
      # end

      get "/api" do |_env|
        error_message = nil
        Tokei::Api::Views::Renderer.render_api(error_message)
      end

      # GET /badges endpoint (badges documentation page)
      get "/badges" do |_env|
        error_message = nil
        Tokei::Api::Views::Renderer.render_badges(error_message)
      end

      # Error handling
      error 404 do |env|
        env.response.content_type = "text/html"
        Tokei::Api::Views::Renderer.render_error("Page not found")
      end

      error 500 do |env, ex|
        env.response.content_type = "text/html"
        log_web_error("web.error.500", ex, {
          "req_id" => request_id,
          "route"  => env.request.path,
        })
        Tokei::Api::Views::Renderer.render_error("Internal Server Error")
      end

      # Serve static files
      public_folder "public"
    end
  end
end
