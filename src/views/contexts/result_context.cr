require "ecr"
require "./base_context"
require "../../models/analysis"
require "../../services/tokei_service"
require "json"
require "uri"

module Tokei::Api::Views::Contexts
  # Context for results page
  class ResultContext < BaseContext
    property analysis : Tokei::Api::Models::Analysis
    property result_json : JSON::Any

    # Badge types
    enum BadgeType
      Lines
      Language
      Languages
      Ratio
    end

    def initialize(@analysis, @result_json, @error_message = nil)
      super(@error_message)
    end

    # Check if the repository URL is from GitHub
    def is_github_repo?
      Tokei::Api::Services::TokeiService.is_github_repo?(@analysis.repo_url)
    end

    # Extract GitHub owner and repo name
    def github_info
      Tokei::Api::Services::TokeiService.extract_github_info(@analysis.repo_url)
    end

    # Generate badge URL for the specified type
    def badge_url(type : BadgeType) : String
      base_url = server_base_url

      if is_github_repo? && (info = github_info)
        owner, repo = info
        badge_path = "#{base_url}/badge/github/#{owner}/#{repo}/#{type.to_s.downcase}"
      else
        badge_path = "#{base_url}/api/badge/#{type.to_s.downcase}?url=#{@analysis.repo_url}"
      end

      "https://img.shields.io/endpoint?url=#{URI.encode_www_form(badge_path)}"
    end

    # Generate markdown for badge
    def badge_markdown(type : BadgeType, label : String) : String
      badge_img = badge_url(type)

      if is_github_repo? && (info = github_info)
        owner, repo = info
        link_url = "#{server_base_url}/github/#{owner}/#{repo}"
      else
        link_url = "#{server_base_url}/analyze?url=#{URI.encode_www_form(@analysis.repo_url)}"
      end

      "[![#{label}](#{badge_img})](#{link_url})"
    end

    # Get link URL for badges
    def badge_link_url : String
      if is_github_repo? && (info = github_info)
        owner, repo = info
        "#{server_base_url}/github/#{owner}/#{repo}"
      else
        "#{server_base_url}/analyze?url=#{URI.encode_www_form(@analysis.repo_url)}"
      end
    end

    # Get GitHub Next repo-visualization service URL
    # This service is part of GitHub Next's Repo Visualization project
    # which provides a visual representation of repository structure and relationships.
    # For more information, visit: https://githubnext.com/projects/repo-visualization/
    def github_next_visualization_url : String
      # Get URL from environment variable or use default
      ENV["GITHUB_NEXT_VISUALIZATION_URL"]? || "https://mango-dune-07a8b7110.1.azurestaticapps.net"
    end

    ECR.def_to_s "#{__DIR__}/../../views/result.ecr"
  end
end
