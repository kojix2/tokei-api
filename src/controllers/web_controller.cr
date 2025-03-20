require "kemal"
require "../services/tokei_service"
require "../models/analysis"
require "../views/renderer"

module Tokei::Api::Controllers
  # Controller for Web
  module WebController
    # Setup Web endpoints
    def self.setup
      # GET / endpoint (home page)
      get "/" do |env|
        error_message = nil
        Tokei::Api::Views::Renderer.render_index(error_message)
      end

      # POST /analyze endpoint (form submission)
      post "/analyze" do |env|
        begin
          # Get repository URL from form
          repo_url = env.params.body["repo_url"]

          # URL validation
          unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
            env.response.status_code = 400
            error_message = "Invalid repository URL"
            next Tokei::Api::Views::Renderer.render_index(error_message)
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
          env.redirect "/result/#{analysis.id}"
        rescue ex
          error_message = "Error: #{ex.message}"
          Tokei::Api::Views::Renderer.render_index(error_message)
        end
      end

      # GET /result/:id endpoint (results display page)
      get "/result/:id" do |env|
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
