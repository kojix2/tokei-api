require "kemal"
require "../services/tokei_service"
require "../models/analysis"

module Tokei::Api::Controllers
  # Web用コントローラー
  module WebController
    # Webエンドポイントの設定
    def self.setup
      # GET / エンドポイント（トップページ）
      get "/" do |env|
        # 最近の解析結果を取得
        recent_analyses = Tokei::Api::Models::Analysis.list_recent(5)
        error_message = nil

        render "src/views/index.ecr", "src/views/layout.ecr", {recent_analyses: recent_analyses, error_message: error_message}
      end

      # POST /analyze エンドポイント（フォーム送信）
      post "/analyze" do |env|
        begin
          # フォームからリポジトリURLを取得
          repo_url = env.params.body["repo_url"]

          # URLのバリデーション
          unless Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
            env.response.status_code = 400
            error_message = "Invalid repository URL"
            env.set "recent_analyses", [] of Tokei::Api::Models::Analysis
            env.set "error_message", error_message
            return render "src/views/index.ecr", "src/views/layout.ecr"
          end

          # 既存の解析結果を検索
          existing_analyses = Tokei::Api::Models::Analysis.find_by_repo_url(repo_url)

          if !existing_analyses.empty? && existing_analyses[0].analyzed_at.not_nil! > Time.utc - 24.hours
            # 最近の解析結果がある場合はそれを使用
            analysis = existing_analyses[0]
          else
            # リポジトリの解析
            result = Tokei::Api::Services::TokeiService.analyze_repo(repo_url)

            # データベースに保存
            analysis = Tokei::Api::Models::Analysis.new(repo_url: repo_url, result: result)
            analysis.save
          end

          # 結果ページにリダイレクト
          env.redirect "/result/#{analysis.id}"
        rescue ex
          error_message = "Error: #{ex.message}"
          env.set "recent_analyses", Tokei::Api::Models::Analysis.list_recent(5)
          env.set "error_message", error_message
          render "src/views/index.ecr", "src/views/layout.ecr"
        end
      end

      # GET /result/:id エンドポイント（結果表示ページ）
      get "/result/:id" do |env|
        begin
          id = env.params.url["id"]

          analysis = Tokei::Api::Models::Analysis.find(id)

          if analysis.nil?
            env.response.status_code = 404
            error_message = "Analysis not found"
            env.set "recent_analyses", Tokei::Api::Models::Analysis.list_recent(5)
            env.set "error_message", error_message
            return render "src/views/index.ecr", "src/views/layout.ecr"
          end

          # 解析結果をJSONからパース
          result_json = JSON.parse(analysis.result)

          env.set "analysis", analysis
          env.set "result_json", result_json
          env.set "error_message", nil
          render "src/views/result.ecr", "src/views/layout.ecr"
        rescue ex
          env.response.status_code = 500
          error_message = "Error: #{ex.message}"
          env.set "recent_analyses", Tokei::Api::Models::Analysis.list_recent(5)
          env.set "error_message", error_message
          render "src/views/index.ecr", "src/views/layout.ecr"
        end
      end

      # 静的ファイルの提供
      public_folder "public"
    end
  end
end
