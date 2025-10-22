require "kemal"
require "../services/tokei_service"
require "../models/analysis"
require "../views/renderer"
require "../views/contexts/layout_context"

module Tokei::Api::Controllers
  # Controller for Web
  module WebController
    # Detect common social preview bots (Twitter, Facebook, LinkedIn, Slack, Discord, etc.)
    private def self.social_bot?(ua : String?) : Bool
      return false unless ua
      !!(ua =~ /Twitterbot|facebookexternalhit|LinkedInBot|Slackbot|Discordbot|WhatsApp|TelegramBot|Mastodon|Line|iMessage/i)
    end

    # Build absolute base URL based on headers or ENV
    private def self.base_url(env : HTTP::Server::Context) : String
      return ENV["BASE_URL"] if ENV["BASE_URL"]?
      scheme = env.request.headers["X-Forwarded-Proto"]? || ENV["DEFAULT_SCHEME"]? || "https"
      host   = env.request.headers["X-Forwarded-Host"]? || env.request.host_with_port
      "#{scheme}://#{host}"
    end
    # Process analyze request (common logic for GET and POST)
    private def self.process_analyze_request(env, repo_url)
      # URL validation
      unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
        env.response.status_code = 400
        error_message = "Invalid repository URL"
        return Tokei::Api::Views::Renderer.render_index(error_message)
      end

      # Search for existing analysis results
      existing_analyses = Tokei::Api::Models::Analysis.find_by_repo_url(repo_url)

      if !existing_analyses.empty? && existing_analyses[0].analyzed_at.not_nil! > Time.utc - 24.hours
        # Use recent analysis results if available
        analysis = existing_analyses[0]
      else
        # Analyze repository
        result = Tokei::Api::Services::TokeiService.analyze_repo(repo_url)

        # Save to database
        analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
        analysis.save
      end

      # Redirect to results page
      env.redirect "/analyses/#{analysis.id}"
    rescue ex
      error_message = "Error: #{ex.message}"
      Tokei::Api::Views::Renderer.render_index(error_message)
    end

    # Process GitHub repository analyze request
    private def self.process_github_analyze_request(env, owner, repo)
      # Construct GitHub repository URL
      repo_url = "https://github.com/#{owner}/#{repo}"

      # Use the common analyze request processing
      process_analyze_request(env, repo_url)
    end

    # Setup Web endpoints
    def self.setup
      # GET / endpoint (home page)
      get "/" do |env|
        error_message = nil
        Tokei::Api::Views::Renderer.render_index(error_message)
      end

      # GET /analyze endpoint (for badge links) - redirect to /analyses
      get "/analyze" do |env|
        # Get repository URL from query parameters
        repo_url = env.params.query["url"]
        process_analyze_request(env, repo_url)
      end

      # POST /analyze endpoint (form submission) - redirect to /analyses
      post "/analyze" do |env|
        # Get repository URL from form
        repo_url = env.params.body["url"]
        process_analyze_request(env, repo_url)
      end

      # POST /analyses endpoint (form submission - new API structure)
      post "/analyses" do |env|
        # Get repository URL from form
        repo_url = env.params.body["url"]
        process_analyze_request(env, repo_url)
      end

      # GET /result/:id endpoint (results display page) - redirect to /analyses/:id
      get "/result/:id" do |env|
        id = env.params.url["id"]
        env.redirect "/analyses/#{id}"
      end

      # GET /analyses/:id endpoint (results display page - new API structure)
      get "/analyses/:id" do |env|
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
          error_message = "Error: #{ex.message}"
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
        owner = env.params.url["owner"]
        repo  = env.params.url["repo"]

        if social_bot?(env.request.headers["User-Agent"]?)
          base  = base_url(env)
          image = "#{base}/og/github/#{owner}/#{repo}?format=png"

          meta = String.build do |io|
            io << %(<meta property="og:type" content="website">)
            io << %(<meta property="og:title" content="#{owner}/#{repo}">)
            io << %(<meta property="og:description" content="Language breakdown by tokei">)
            io << %(<meta property="og:url" content="#{base}/github/#{owner}/#{repo}">)
            io << %(<meta property="og:image" content="#{image}">)
            io << %(<meta property="og:image:width" content="1200">)
            io << %(<meta property="og:image:height" content="630">)
            io << %(<meta name="twitter:card" content="summary_large_image">)
          end

          body = String.build do |io|
            io << %(<h1>#{owner}/#{repo}</h1>)
            io << %(<p>Share this URL on social networks to show a bar chart preview.</p>)
            io << %(<img src="#{image}" alt="OG Preview" width="600" height="315">)
          end

          html = Tokei::Api::Views::Contexts::LayoutContext.new(body, nil, meta).to_s
          env.response.content_type = "text/html; charset=utf-8"
          next html
        end

        # Fallback for regular browsers: perform analysis and redirect
        begin
          process_github_analyze_request(env, owner, repo)
        rescue ex
          env.response.status_code = 500
          error_message = "Error: #{ex.message}"
          Tokei::Api::Views::Renderer.render_index(error_message)
        end
      end

      # POST /cleanup endpoint (delete old data)
      post "/cleanup" do |env|
        begin
          deleted_count = Tokei::Api::Models::Analysis.cleanup_old_data
          env.response.status_code = 200
          env.response.print "Deleted #{deleted_count} old records."
        rescue ex
          env.response.status_code = 500
          env.response.print "Error during cleanup: #{ex.message}"
        end
      end

      get "/api" do |env|
        error_message = nil
        Tokei::Api::Views::Renderer.render_api(error_message)
      end

      # GET /badges endpoint (badges documentation page)
      get "/badges" do |env|
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
        Tokei::Api::Views::Renderer.render_error("Internal Server Error: #{ex.message}")
      end

      # Serve static files
      public_folder "public"
    end
  end
end
