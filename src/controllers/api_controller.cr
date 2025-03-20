require "kemal"
require "json"
require "../services/tokei_service"
require "../models/analysis"

module Tokei::Api::Controllers
  # API用コントローラー
  module ApiController
    # APIエンドポイントの設定
    def self.setup
      # POST /api/analyze エンドポイント
      post "/api/analyze" do |env|
        begin
          # リクエストボディからリポジトリURLを取得
          request_body = env.request.body.not_nil!.gets_to_end
          request_json = JSON.parse(request_body)

          repo_url = request_json["repo_url"].as_s

          # URLのバリデーション
          unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
            env.response.status_code = 400
            next {error: "Invalid repository URL"}.to_json
          end

          # 既存の解析結果を検索
          existing_analyses = Tokei::Api::Models::Analysis.find_by_repo_url(repo_url)

          # 最近の解析結果がある場合はそれを返す（24時間以内）
          if !existing_analyses.empty? && existing_analyses[0].analyzed_at.not_nil! > Time.utc - 24.hours
            env.response.content_type = "application/json"
            next existing_analyses[0].result.to_json
          end

          # リポジトリの解析
          result = Tokei::Api::Services::TokeiService.analyze_repo(repo_url)

          # データベースに保存
          analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
          analysis.save

          # 結果を返す
          env.response.content_type = "application/json"
          result.to_json
        rescue ex : JSON::ParseException
          env.response.status_code = 400
          {error: "Invalid JSON format"}.to_json
        rescue ex : KeyError
          env.response.status_code = 400
          {error: "Missing required field: repo_url"}.to_json
        rescue ex
          env.response.status_code = 500
          {error: "Internal server error: #{ex.message}"}.to_json
        end
      end

      # GET /api/analysis/:id エンドポイント（特定の解析結果を取得）
      get "/api/analysis/:id" do |env|
        begin
          id = env.params.url["id"]

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            next {error: "Analysis not found"}.to_json
          end

          env.response.content_type = "application/json"
          analysis.result.to_json
        rescue ex
          env.response.status_code = 500
          {error: "Internal server error: #{ex.message}"}.to_json
        end
      end
    end
  end
end
