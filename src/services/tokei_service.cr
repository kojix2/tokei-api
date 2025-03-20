require "json"
require "file_utils"
require "random"
require "dotenv"

module Tokei::Api::Services
  # Service class for executing tokei command
  class TokeiService
    # Load environment variables
    Dotenv.load

    # Base path for temporary directory
    TEMP_DIR_BASE = ENV["TEMP_DIR"]? || "/tmp/tokei-api"

    # Timeout for git clone operation (in seconds)
    CLONE_TIMEOUT = ENV["CLONE_TIMEOUT_SECONDS"]?.try(&.to_i) || 30

    # Repository URL validation
    def self.valid_repo_url?(url : String) : Bool
      # GitHub HTTPS or SSH URL patterns
      github_https = /^https:\/\/github\.com\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      github_ssh = /^git@github\.com:[\w.-]+\/[\w.-]+(?:\.git)?$/

      # GitLab HTTPS or SSH URL patterns
      gitlab_https = /^https:\/\/gitlab\.com\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      gitlab_ssh = /^git@gitlab\.com:[\w.-]+\/[\w.-]+(?:\.git)?$/

      # Bitbucket HTTPS or SSH URL patterns
      bitbucket_https = /^https:\/\/bitbucket\.org\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      bitbucket_ssh = /^git@bitbucket\.org:[\w.-]+\/[\w.-]+(?:\.git)?$/

      # Generic git URL patterns
      generic_https = /^https:\/\/[\w.-]+\.[\w.-]+\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      generic_ssh = /^git@[\w.-]+\.[\w.-]+:[\w.-]+\/[\w.-]+(?:\.git)?$/

      !!(url.match(github_https) || url.match(github_ssh) ||
        url.match(gitlab_https) || url.match(gitlab_ssh) ||
        url.match(bitbucket_https) || url.match(bitbucket_ssh) ||
        url.match(generic_https) || url.match(generic_ssh))
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
