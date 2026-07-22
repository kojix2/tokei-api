require "../models/analysis"
require "../models/analysis_failure"
require "./log_service"
require "./tokei_service"

module Tokei::Api::Services
  module AnalysisService
    CACHE_TTL    = 24.hours
    LOCK_STRIPES = 64

    @@locks = Array(Mutex).new(LOCK_STRIPES) { Mutex.new }

    class RetrySuppressedError < Exception
      getter retry_after : Time

      def initialize(@retry_after : Time)
        super("Repository analysis is temporarily suppressed")
      end
    end

    def self.get_for_repo(repo_url : String, req_id : String = LogService.request_id) : Tokei::Api::Models::Analysis
      raise "Invalid repository URL" unless TokeiService.valid_repo_url?(repo_url)
      repo_url = TokeiService.normalize_repo_url(repo_url)

      if analysis = fresh_analysis(repo_url, req_id)
        return analysis
      end

      with_repo_lock(repo_url, req_id) do
        if analysis = fresh_analysis(repo_url, req_id, event: "analysis.cache.hit_after_wait")
          return analysis
        end

        if retry_after = Tokei::Api::Models::AnalysisFailure.suppressed_until(repo_url)
          return suppressed_result(repo_url, req_id, retry_after)
        end

        LogService.cache_event("analysis.cache.miss", repo_url, req_id)

        begin
          result = TokeiService.analyze_repo(repo_url, req_id)
        rescue ex : TokeiService::RepositoryError
          error_type = error_type_for(ex)
          failure_count, retry_after = Tokei::Api::Models::AnalysisFailure.record(repo_url, error_type)
          LogService.info("analysis.failure.recorded", {
            "req_id"        => req_id,
            "repo_url"      => LogService.mask_url(repo_url),
            "error_type"    => error_type,
            "failure_count" => failure_count.to_s,
            "retry_after"   => Tokei::Api::Models::Analysis.timestamp(retry_after),
          })
          return suppressed_result(repo_url, req_id, retry_after)
        end

        analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
        saved = analysis.save
        raise "Failed to persist analysis result" unless saved && analysis.id
        Tokei::Api::Models::AnalysisFailure.clear(repo_url)

        analysis
      end
    end

    private def self.fresh_analysis(repo_url : String, req_id : String, event : String = "analysis.cache.hit") : Tokei::Api::Models::Analysis?
      analysis = Tokei::Api::Models::Analysis.find_latest_by_repo_url(repo_url)
      return unless analysis && fresh?(analysis)

      LogService.cache_event(event, repo_url, req_id, analysis)
      analysis
    end

    private def self.fresh?(analysis : Tokei::Api::Models::Analysis) : Bool
      analysis.analyzed_at.try(&.> Time.utc - CACHE_TTL) || false
    end

    private def self.suppressed_result(repo_url : String, req_id : String, retry_after : Time) : Tokei::Api::Models::Analysis
      if stale = Tokei::Api::Models::Analysis.find_latest_by_repo_url(repo_url)
        LogService.info("analysis.stale.served", {
          "req_id"      => req_id,
          "repo_url"    => LogService.mask_url(repo_url),
          "analysis_id" => stale.id.to_s,
          "analyzed_at" => stale.analyzed_at.try { |time| Tokei::Api::Models::Analysis.timestamp(time) } || "",
        })
        return stale
      end

      raise RetrySuppressedError.new(retry_after)
    end

    private def self.error_type_for(ex : TokeiService::RepositoryError) : String
      case ex
      when TokeiService::CloneTimeoutError    then "clone_timeout"
      when TokeiService::CloneFailedError     then "clone_failed"
      when TokeiService::AnalysisTimeoutError then "analysis_timeout"
      when TokeiService::AnalysisFailedError  then "analysis_failed"
      else                                         "unknown"
      end
    end

    private def self.with_repo_lock(repo_url : String, req_id : String, &)
      stripe = lock_stripe(repo_url)
      lock = @@locks[stripe]
      LogService.info("analysis.lock.wait", {
        "req_id"   => req_id,
        "repo_url" => LogService.mask_url(repo_url),
        "stripe"   => stripe.to_s,
      })

      lock.synchronize do
        LogService.info("analysis.lock.acquired", {
          "req_id"   => req_id,
          "repo_url" => LogService.mask_url(repo_url),
          "stripe"   => stripe.to_s,
        })
        yield
      end
    end

    private def self.lock_stripe(repo_url : String) : Int32
      repo_url.hash.remainder(LOCK_STRIPES).to_i
    end
  end
end
