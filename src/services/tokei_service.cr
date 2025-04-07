require "json"
require "file_utils"
require "random"
require "dotenv"

module Tokei::Api::Services
  # Service class for executing tokei command
  class TokeiService
    # Load environment variables (skip in test environment)
    Dotenv.load unless ENV["CRYSTAL_ENV"]? == "test"

    # Base path for temporary directory
    TEMP_DIR_BASE = ENV["TEMP_DIR"]? || "/tmp/tokei-api"

    # Timeout for git clone operation (in seconds)
    CLONE_TIMEOUT = ENV["CLONE_TIMEOUT_SECONDS"]?.try(&.to_i) || 30

    # Common URL patterns
    # GitHub URL patterns
    GITHUB_HTTPS_VALIDATION = /^https:\/\/github\.com\/[\w.-]+\/[\w.-]+(?:\.git|\/)?$/
    GITHUB_SSH_VALIDATION   = /^git@github\.com:[\w.-]+\/[\w.-]+(?:\.git|\/)?$/

    # GitHub URL patterns with capture groups for owner and repo
    # The regex captures the owner and repository name, removing any .git extension at the end
    GITHUB_HTTPS_EXTRACTION = /https?:\/\/(?:www\.)?github\.com\/([^\/]+)\/([a-zA-Z0-9._-]+?)(?:\.git)?$/
    GITHUB_SSH_EXTRACTION   = /git@github\.com:([^\/]+)\/([a-zA-Z0-9._-]+?)(?:\.git)?$/

    # GitLab URL patterns
    GITLAB_HTTPS = /^https:\/\/gitlab\.com\/[\w.-]+\/[\w.-]+(?:\.git|\/)?$/
    GITLAB_SSH   = /^git@gitlab\.com:[\w.-]+\/[\w.-]+(?:\.git|\/)?$/

    # Bitbucket URL patterns
    BITBUCKET_HTTPS = /^https:\/\/bitbucket\.org\/[\w.-]+\/[\w.-]+(?:\.git|\/)?$/
    BITBUCKET_SSH   = /^git@bitbucket\.org:[\w.-]+\/[\w.-]+(?:\.git|\/)?$/

    # Generic git URL patterns
    GENERIC_HTTPS = /^https:\/\/[\w.-]+\.[\w.-]+\/[\w.-]+\/[\w.-]+(?:\.git|\/)?$/
    GENERIC_SSH   = /^git@[\w.-]+\.[\w.-]+:[\w.-]+\/[\w.-]+(?:\.git|\/)?$/

    # Repository URL validation
    def self.valid_repo_url?(url : String) : Bool
      !!(url.match(GITHUB_HTTPS_VALIDATION) || url.match(GITHUB_SSH_VALIDATION) ||
        url.match(GITLAB_HTTPS) || url.match(GITLAB_SSH) ||
        url.match(BITBUCKET_HTTPS) || url.match(BITBUCKET_SSH) ||
        url.match(GENERIC_HTTPS) || url.match(GENERIC_SSH))
    end

    # Check if the repository URL is from GitHub
    def self.is_github_repo?(url : String) : Bool
      !!(url.match(GITHUB_HTTPS_EXTRACTION) || url.match(GITHUB_SSH_EXTRACTION))
    end

    # Extract owner and repo from GitHub URL
    def self.extract_github_info(url : String) : {String, String}?
      if match = url.match(GITHUB_HTTPS_EXTRACTION)
        owner = match[1]
        repo = match[2]
        # Remove all .git extensions from the end of the repo name
        repo = repo.gsub(/\.git(?:\.git)*$/, "")
        return {owner, repo}
      elsif match = url.match(GITHUB_SSH_EXTRACTION)
        owner = match[1]
        repo = match[2]
        # Remove all .git extensions from the end of the repo name
        repo = repo.gsub(/\.git(?:\.git)*$/, "")
        return {owner, repo}
      end

      nil
    end

    # Analyze repository
    def self.analyze_repo(repo_url : String) : String
      # URL validation
      raise "Invalid repository URL: #{repo_url}" unless valid_repo_url?(repo_url)

      # Create temporary directory
      random_suffix = Random::Secure.hex(8)
      temp_dir = File.join(TEMP_DIR_BASE, random_suffix)

      begin
        # Create directory if it doesn't exist
        FileUtils.mkdir_p(TEMP_DIR_BASE) unless Dir.exists?(TEMP_DIR_BASE)

        # Clone repository with timeout and single-branch options
        clone_command = "timeout #{CLONE_TIMEOUT}s git clone --depth 1 --single-branch #{repo_url} #{temp_dir}"
        clone_result = system(clone_command)

        unless clone_result
          # Check if the failure was due to timeout
          if $?.exit_code == 124
            raise "Repository cloning timed out after #{CLONE_TIMEOUT} seconds. The repository may be too large."
          else
            raise "Failed to clone repository: #{repo_url}. Please check the URL and try again."
          end
        end

        # Execute tokei command
        tokei_command = "cd #{temp_dir} && tokei --output json"
        output = `#{tokei_command}`

        if output.empty?
          raise "Failed to analyze repository with tokei"
        end

        return output
      ensure
        # Remove temporary directory
        FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
      end
    end
  end
end
