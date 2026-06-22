require "../models/analysis"
require "./log_service"
require "./tokei_service"

module Tokei::Api::Services
  module AnalysisService
    CACHE_TTL    = 24.hours
    LOCK_STRIPES = 64

    @@locks = Array(Mutex).new(LOCK_STRIPES) { Mutex.new }

    def self.get_for_repo(repo_url : String, req_id : String = LogService.request_id) : Tokei::Api::Models::Analysis
      raise "Invalid repository URL" unless TokeiService.valid_repo_url?(repo_url)

      if analysis = fresh_analysis(repo_url, req_id)
        return analysis
      end

      with_repo_lock(repo_url, req_id) do
        if analysis = fresh_analysis(repo_url, req_id, event: "analysis.cache.hit_after_wait")
          return analysis
        end

        LogService.cache_event("analysis.cache.miss", repo_url, req_id)

        result = TokeiService.analyze_repo(repo_url, req_id)
        analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
        saved = analysis.save
        raise "Failed to persist analysis result" unless saved && analysis.id

        analysis
      end
    end

    private def self.fresh_analysis(repo_url : String, req_id : String, event : String = "analysis.cache.hit") : Tokei::Api::Models::Analysis?
      analysis = Tokei::Api::Models::Analysis.find_latest_by_repo_url(repo_url)
      return nil unless analysis && fresh?(analysis)

      LogService.cache_event(event, repo_url, req_id, analysis)
      analysis
    end

    private def self.fresh?(analysis : Tokei::Api::Models::Analysis) : Bool
      analysis.analyzed_at.try(&.> Time.utc - CACHE_TTL) || false
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
