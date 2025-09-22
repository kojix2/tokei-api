require "kemal"
require "json"
require "../services/tokei_service"
require "../models/analysis"

module Tokei::Api::Controllers
  # Controller for API
  module ApiController
    # Format numbers for display (e.g., 1.2k for 1200)
    private def self.format_number(num : Int32)
      if num >= 1_000_000
        "%.1fM" % (num / 1_000_000.0)
      elsif num >= 1_000
        "%.1fk" % (num / 1_000.0)
      else
        num.to_s
      end
    end

    # Generate badge data based on type and analysis
    private def self.generate_badge_data(badge_type : String, analysis)
      case badge_type
      when "lines"
        # Use stored total lines
        {
          schemaVersion: 1,
          label:         "Lines of Code",
          message:       format_number(analysis.total_lines || 0),
          color:         "blue",
        }
      when "language"
        # Use stored top language
        {
          schemaVersion: 1,
          label:         "Top Language",
          message:       analysis.top_language || "Unknown",
          color:         "brightgreen",
        }
      when "languages"
        # Use stored language count
        {
          schemaVersion: 1,
          label:         "Languages",
          message:       (analysis.language_count || 0).to_s,
          color:         "orange",
        }
      when "ratio"
        # Use stored code to comment ratio
        ratio = analysis.code_comment_ratio || 0.0

        {
          schemaVersion: 1,
          label:         "Code to Comment",
          message:       "#{ratio.round(1)}:1",
          color:         "blueviolet",
        }
      else
        raise "Invalid badge type: #{badge_type}"
      end
    end

    # Get the most recent analysis for a repository URL
    private def self.get_analysis_for_repo(repo_url : String)
      # URL validation
      unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
        raise "Invalid repository URL"
      end

      # Search for existing analysis results
      existing_analyses = Tokei::Api::Models::Analysis.find_by_repo_url(repo_url)

      # Check if we have any recent analysis results (within 24 hours)
      if !existing_analyses.empty? && existing_analyses[0].analyzed_at.not_nil! > Time.utc - 24.hours
        return existing_analyses[0]
      end

      # Analyze repository
      result = Tokei::Api::Services::TokeiService.analyze_repo(repo_url)

      # Save to database
      analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
      analysis.save

      return analysis
    end

    # Setup API endpoints
    def self.setup
      # GET /api/badge/:type endpoint (for dynamic shields.io badges)
      get "/api/badge/:type" do |env|
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
          existing_analyses = Tokei::Api::Models::Analysis.find_by_repo_url(repo_url)

          # Check if we have any analysis results
          if existing_analyses.empty?
            env.response.status_code = 404
            next {
              schemaVersion: 1,
              label:         "error",
              message:       "No analysis found",
              color:         "red",
            }.to_json
          end

          # Use the most recent analysis
          analysis = existing_analyses[0]

          # Generate badge data
          begin
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue ex
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = 500
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
        begin
          # Get repository URL from request body
          request_body = env.request.body.not_nil!.gets_to_end
          request_json = JSON.parse(request_body)

          repo_url = request_json["url"]?.try(&.as_s) || ""

          if repo_url.empty?
            raise KeyError.new("Missing required field: url")
          end

          # Get analysis
          analysis = get_analysis_for_repo(repo_url)

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
                self:      "/api/analyses/#{analysis.id.to_s}",
                languages: "/api/analyses/#{analysis.id.to_s}/languages",
                web:       "/analyses/#{analysis.id.to_s}",
              },
            },
          }

          # Return results
          env.response.status_code = 201 # Created
          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex : JSON::ParseException
          env.response.status_code = 400
          {error: {code: "invalid_request", message: "Invalid JSON format", status: 400}}.to_json
        rescue ex : KeyError
          env.response.status_code = 400
          {error: {code: "invalid_request", message: "Missing required field: url", status: 400}}.to_json
        rescue ex
          env.response.status_code = 500
          {error: {code: "server_error", message: "Internal server error: #{ex.message}", status: 500}}.to_json
        end
      end

      # GET /api/analyses endpoint (retrieve analysis result by repository URL)
      get "/api/analyses" do |env|
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

          # Find existing analysis results for the repository
          existing_analyses = Tokei::Api::Models::Analysis.find_by_repo_url(repo_url)

          # Return 404 if no analysis is found
          if existing_analyses.empty?
            env.response.status_code = 404
            next {error: {code: "not_found", message: "No analysis found for the given URL", status: 404}}.to_json
          end

          # Use the most recent analysis (first element in the array)
          analysis = existing_analyses[0]

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
                self:      "/api/analyses/#{analysis.id.to_s}",
                languages: "/api/analyses/#{analysis.id.to_s}/languages",
                web:       "/analyses/#{analysis.id.to_s}",
              },
            },
          }

          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex
          env.response.status_code = 500
          {error: {code: "server_error", message: "Internal server error: #{ex.message}", status: 500}}.to_json
        end
      end

      # GET /api/analyses/:id endpoint (retrieve specific analysis results)
      get "/api/analyses/:id" do |env|
        begin
          id = env.params.url["id"]

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            next {error: {code: "not_found", message: "Analysis not found", status: 404}}.to_json
          end

          # Extract languages data from result
          languages_data = {} of String => Hash(String, Int32)
          result_json = analysis.result.as_h

          result_json.each do |language, stats|
            next if language == "Total"
            stats_obj = stats.as_h

            files = stats_obj["reports"]?.try(&.as_a.size) || stats_obj["files"]?.try(&.as_i) || 0
            code = stats_obj["code"]?.try(&.as_i) || 0
            comments = stats_obj["comments"]?.try(&.as_i) || 0
            blanks = stats_obj["blanks"]?.try(&.as_i) || 0

            languages_data[language.to_s] = {
              "files"    => files.to_i,
              "code"     => code.to_i,
              "comments" => comments.to_i,
              "blanks"   => blanks.to_i,
            }
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
              languages: languages_data,
              links:     {
                self:      "/api/analyses/#{analysis.id.to_s}",
                languages: "/api/analyses/#{analysis.id.to_s}/languages",
                web:       "/analyses/#{analysis.id.to_s}",
              },
            },
          }

          env.response.content_type = "application/json"
          response_data.to_json
        rescue ex
          env.response.status_code = 500
          {error: {code: "server_error", message: "Internal server error: #{ex.message}", status: 500}}.to_json
        end
      end

      # GET /api/analyses/:id/languages endpoint (retrieve language statistics)
      get "/api/analyses/:id/languages" do |env|
        begin
          id = env.params.url["id"]

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            next {error: {code: "not_found", message: "Analysis not found", status: 404}}.to_json
          end

          # Extract languages data from result
          languages_data = {} of String => Hash(String, Int32 | Float64)
          result_json = analysis.result.as_h
          total_code = 0

          # First pass to calculate total code
          result_json.each do |language, stats|
            next if language == "Total"
            stats_obj = stats.as_h
            code = stats_obj["code"]?.try(&.as_i) || 0
            total_code += code.to_i
          end

          # Second pass to build language data with percentages
          result_json.each do |language, stats|
            next if language == "Total"
            stats_obj = stats.as_h

            files = stats_obj["reports"]?.try(&.as_a.size) || stats_obj["files"]?.try(&.as_i) || 0
            code = stats_obj["code"]?.try(&.as_i) || 0
            comments = stats_obj["comments"]?.try(&.as_i) || 0
            blanks = stats_obj["blanks"]?.try(&.as_i) || 0

            percentage = total_code > 0 ? (code.to_i.to_f / total_code.to_f * 100).round(1) : 0.0

            languages_data[language.to_s] = {
              "files"      => files.to_i,
              "code"       => code.to_i,
              "comments"   => comments.to_i,
              "blanks"     => blanks.to_i,
              "percentage" => percentage,
            }
          end

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
          env.response.status_code = 500
          {error: {code: "server_error", message: "Internal server error: #{ex.message}", status: 500}}.to_json
        end
      end

      # GET /api/analyses/:id/badges/:type endpoint (retrieve badge data)
      get "/api/analyses/:id/badges/:type" do |env|
        begin
          id = env.params.url["id"]
          badge_type = env.params.url["type"]

          env.response.content_type = "application/json"

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            next {
              schemaVersion: 1,
              label:         "error",
              message:       "Analysis not found",
              color:         "red",
            }.to_json
          end

          # Generate badge data
          begin
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue ex
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = 500
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
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_analysis_for_repo(repo_url)

          # Extract languages data from result
          languages_data = {} of String => Hash(String, Int32)
          result_json = analysis.result.as_h

          result_json.each do |language, stats|
            next if language == "Total"
            stats_obj = stats.as_h

            files = stats_obj["reports"]?.try(&.as_a.size) || stats_obj["files"]?.try(&.as_i) || 0
            code = stats_obj["code"]?.try(&.as_i) || 0
            comments = stats_obj["comments"]?.try(&.as_i) || 0
            blanks = stats_obj["blanks"]?.try(&.as_i) || 0

            languages_data[language.to_s] = {
              "files"    => files.to_i,
              "code"     => code.to_i,
              "comments" => comments.to_i,
              "blanks"   => blanks.to_i,
            }
          end

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
          env.response.status_code = 500
          {error: {code: "server_error", message: "Internal server error: #{ex.message}", status: 500}}.to_json
        end
      end

      # GET /api/github/:owner/:repo/languages endpoint (retrieve language statistics)
      get "/api/github/:owner/:repo/languages" do |env|
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_analysis_for_repo(repo_url)

          # Extract languages data from result
          languages_data = {} of String => Hash(String, Int32 | Float64)
          result_json = analysis.result.as_h
          total_code = 0

          # First pass to calculate total code
          result_json.each do |language, stats|
            next if language == "Total"
            stats_obj = stats.as_h
            code = stats_obj["code"]?.try(&.as_i) || 0
            total_code += code.to_i
          end

          # Second pass to build language data with percentages
          result_json.each do |language, stats|
            next if language == "Total"
            stats_obj = stats.as_h

            files = stats_obj["reports"]?.try(&.as_a.size) || stats_obj["files"]?.try(&.as_i) || 0
            code = stats_obj["code"]?.try(&.as_i) || 0
            comments = stats_obj["comments"]?.try(&.as_i) || 0
            blanks = stats_obj["blanks"]?.try(&.as_i) || 0

            percentage = total_code > 0 ? (code.to_i.to_f / total_code.to_f * 100).round(1) : 0.0

            languages_data[language.to_s] = {
              "files"      => files.to_i,
              "code"       => code.to_i,
              "comments"   => comments.to_i,
              "blanks"     => blanks.to_i,
              "percentage" => percentage,
            }
          end

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
          env.response.status_code = 500
          {error: {code: "server_error", message: "Internal server error: #{ex.message}", status: 500}}.to_json
        end
      end

      # GET /api/github/:owner/:repo/badges/:type endpoint (retrieve badge data)
      get "/api/github/:owner/:repo/badges/:type" do |env|
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]
          badge_type = env.params.url["type"]

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_analysis_for_repo(repo_url)

          # Generate badge data
          begin
            env.response.content_type = "application/json"
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue ex
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = 500
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
        begin
          owner = env.params.url["owner"]
          repo = env.params.url["repo"]
          badge_type = env.params.url["type"]

          # Construct GitHub repository URL
          repo_url = "https://github.com/#{owner}/#{repo}"

          # Get analysis
          analysis = get_analysis_for_repo(repo_url)

          # Generate badge data
          begin
            env.response.content_type = "application/json"
            badge_data = generate_badge_data(badge_type, analysis)
            badge_data.to_json
          rescue ex
            env.response.status_code = 400
            {
              schemaVersion: 1,
              label:         "error",
              message:       "Invalid badge type",
              color:         "red",
            }.to_json
          end
        rescue ex
          env.response.status_code = 500
          {
            schemaVersion: 1,
            label:         "error",
            message:       "Server error",
            color:         "red",
          }.to_json
        end
      end
    end
  end
end
