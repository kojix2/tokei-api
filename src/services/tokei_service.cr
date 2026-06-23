require "json"
require "file_utils"
require "random"
require "dotenv"
require "./log_service"

module Tokei::Api::Services
  # Service class for executing tokei command
  class TokeiService
    class RepositoryError < Exception
    end

    class CloneTimeoutError < RepositoryError
    end

    class CloneFailedError < RepositoryError
    end

    class AnalysisTimeoutError < RepositoryError
    end

    class AnalysisFailedError < RepositoryError
    end

    # Load environment variables (skip in test environment)
    Dotenv.load if File.exists?(".env") && ENV["CRYSTAL_ENV"]? != "test"

    # Git configuration
    ENV["GIT_TERMINAL_PROMPT"] ||= "0"
    ENV["GIT_ASKPASS"] ||= "/bin/true"
    ENV["GIT_SSH_COMMAND"] ||= "ssh -o BatchMode=yes"

    # Base path for temporary directory
    TEMP_DIR_BASE = ENV["TEMP_DIR"]? || "/tmp/tokei-api"

    # Timeout for git clone operation (in seconds)
    CLONE_TIMEOUT = ENV["CLONE_TIMEOUT_SECONDS"]?.try(&.to_i) || 30

    # Timeout for tokei analysis operation (in seconds)
    TOKEI_TIMEOUT = ENV["TOKEI_TIMEOUT_SECONDS"]?.try(&.to_i) || 30

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
    # Allow ~ and other common user/repo characters
    GENERIC_HTTPS = /^https:\/\/[\w.~:-]+\.[\w.~:-]+\/[\w.~:-]+\/[\w.~:-]+(?:\.git|\/)?$/
    GENERIC_SSH   = /^git@[\w.~:-]+\.[\w.~:-]+:[\w.~:-]+\/[\w.~:-]+(?:\.git|\/)?$/

    # Repository URL validation
    def self.valid_repo_url?(url : String) : Bool
      !!(url.match(GITHUB_HTTPS_VALIDATION) || url.match(GITHUB_SSH_VALIDATION) ||
        url.match(GITLAB_HTTPS) || url.match(GITLAB_SSH) ||
        url.match(BITBUCKET_HTTPS) || url.match(BITBUCKET_SSH) ||
        url.match(GENERIC_HTTPS) || url.match(GENERIC_SSH))
    end

    # Check if the repository URL is from GitHub
    def self.github_repo?(url : String) : Bool
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
    def self.analyze_repo(repo_url : String, request_id : String = LogService.request_id) : String
      # URL validation
      raise "Invalid repository URL" unless valid_repo_url?(repo_url)

      # Create temporary directory
      random_suffix = Random::Secure.hex(8)
      temp_dir = File.join(TEMP_DIR_BASE, random_suffix)
      repo = LogService.mask_url(repo_url)
      analysis_started_at = Time.instant

      begin
        # Create directory if it doesn't exist
        FileUtils.mkdir_p(TEMP_DIR_BASE) unless Dir.exists?(TEMP_DIR_BASE)

        # Clone repository with timeout and single-branch options
        # Use Process.run for safety (no shell interpretation)
        clone_started_at = Time.instant
        LogService.info("repo.clone.start", {
          "req_id"          => request_id,
          "repo_url"        => repo,
          "timeout_seconds" => CLONE_TIMEOUT.to_s,
        })
        clone_error = IO::Memory.new
        clone_result = Process.run(
          "timeout",
          ["#{CLONE_TIMEOUT}s", "git", "clone", "--depth", "1", "--single-branch", "--no-tags", repo_url, temp_dir],
          output: Process::Redirect::Close,
          error: clone_error
        )
        clone_elapsed_ms = elapsed_ms(clone_started_at)

        unless clone_result.success?
          fields = {
            "req_id"     => request_id,
            "repo_url"   => repo,
            "elapsed_ms" => clone_elapsed_ms,
            "stderr"     => LogService.mask_url(clone_error.to_s),
          }.merge(process_status_fields(clone_result))

          # Check if the failure was due to timeout
          if timeout_status?(clone_result, clone_started_at, CLONE_TIMEOUT)
            LogService.warn("repo.clone.timeout", fields.merge({
              "timeout_seconds" => CLONE_TIMEOUT.to_s,
            }))
            raise CloneTimeoutError.new("Repository cloning timed out after #{CLONE_TIMEOUT} seconds")
          else
            LogService.warn("repo.clone.failed", fields)
            raise CloneFailedError.new("Failed to clone repository")
          end
        end
        LogService.info("repo.clone.complete", {
          "req_id"     => request_id,
          "repo_url"   => repo,
          "elapsed_ms" => clone_elapsed_ms,
        })

        # Execute tokei command
        # Use Process.run for safety (no shell interpretation)
        output = IO::Memory.new
        tokei_started_at = Time.instant
        LogService.info("repo.tokei.start", {
          "req_id"          => request_id,
          "repo_url"        => repo,
          "timeout_seconds" => TOKEI_TIMEOUT.to_s,
        })
        tokei_error = IO::Memory.new
        tokei_result = Process.run(
          "timeout",
          ["#{TOKEI_TIMEOUT}s", "tokei", "--output", "json"],
          chdir: temp_dir,
          output: output,
          error: tokei_error
        )
        tokei_elapsed_ms = elapsed_ms(tokei_started_at)

        unless tokei_result.success?
          fields = {
            "req_id"     => request_id,
            "repo_url"   => repo,
            "elapsed_ms" => tokei_elapsed_ms,
            "stderr"     => LogService.mask_url(tokei_error.to_s),
          }.merge(process_status_fields(tokei_result))

          if timeout_status?(tokei_result, tokei_started_at, TOKEI_TIMEOUT)
            LogService.warn("repo.tokei.timeout", fields.merge({
              "timeout_seconds" => TOKEI_TIMEOUT.to_s,
            }))
            raise AnalysisTimeoutError.new("Repository analysis timed out after #{TOKEI_TIMEOUT} seconds")
          else
            LogService.warn("repo.tokei.failed", fields)
            raise AnalysisFailedError.new("Failed to analyze repository with tokei")
          end
        end

        output_string = output.to_s
        if output_string.empty?
          LogService.warn("repo.tokei.empty_output", {
            "req_id"     => request_id,
            "repo_url"   => repo,
            "elapsed_ms" => tokei_elapsed_ms,
          })
          raise AnalysisFailedError.new("Failed to analyze repository with tokei")
        end

        LogService.info("repo.analysis.complete", {
          "req_id"     => request_id,
          "repo_url"   => repo,
          "clone_ms"   => clone_elapsed_ms,
          "tokei_ms"   => tokei_elapsed_ms,
          "elapsed_ms" => elapsed_ms(analysis_started_at),
        })
        output_string
      ensure
        # Remove temporary directory
        FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
      end
    end

    private def self.elapsed_ms(started_at : Time::Instant) : String
      (Time.instant - started_at).total_milliseconds.round.to_i.to_s
    end

    private def self.timeout_status?(status : Process::Status, started_at : Time::Instant, timeout_seconds : Int32) : Bool
      return true if status.normal_exit? && status.exit_code == 124

      elapsed_seconds = (Time.instant - started_at).total_seconds
      status.signal_exit? && elapsed_seconds >= timeout_seconds
    end

    private def self.process_status_fields(status : Process::Status) : Hash(String, String)
      fields = {"exit_status" => status.to_s}

      if status.normal_exit?
        fields["exit_code"] = status.exit_code.to_s
      elsif status.signal_exit?
        fields["exit_signal"] = status.exit_signal.to_s
      end

      fields
    end
  end
end
