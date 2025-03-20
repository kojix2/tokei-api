require "kemal"
require "../services/tokei_service"
require "../models/analysis"
require "../views/renderer"

module Tokei::Api::Controllers
  # Web用コントローラー
  module WebController
    # Webエンドポイントの設定
    def self.setup
      # GET / エンドポイント（トップページ）
      get "/" do |env|
        error_message = nil
        Tokei::Api::Views::Renderer.render_index(error_message)
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
            next Tokei::Api::Views::Renderer.render_index(error_message)
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
          Tokei::Api::Views::Renderer.render_index(error_message)
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
            next Tokei::Api::Views::Renderer.render_index(error_message)
          end

          # 解析結果はすでにJSON::Any
          result_json = analysis.result

          Tokei::Api::Views::Renderer.render_result(analysis, result_json)
        rescue ex
          env.response.status_code = 500
          error_message = "Error: #{ex.message}"
          Tokei::Api::Views::Renderer.render_index(error_message)
        end
      end

      # エラーハンドリング
      error 404 do |env|
        env.response.content_type = "text/html"
        Tokei::Api::Views::Renderer.render_error("ページが見つかりませんでした")
      end

      error 500 do |env, ex|
        env.response.content_type = "text/html"
        Tokei::Api::Views::Renderer.render_error("Internal Server Error: #{ex.message}")
      end

      # 静的ファイルの提供
      public_folder "public"
    end
  end
end
