require "pg"
require "dotenv"

module Tokei::Api::Config
  # データベース接続を管理するモジュール
  module Database
    # 環境変数を読み込む
    Dotenv.load

    # データベース接続URL
    DATABASE_URL = ENV["DATABASE_URL"]? || "postgresql://localhost/tokei-api"

    # データベース接続を取得する
    def self.connection
      PG.connect(DATABASE_URL)
    end

    # データベースの初期化（テーブル作成など）
    def self.setup
      conn = connection
      begin
        # analysesテーブルが存在しない場合は作成
        conn.exec <<-SQL
          CREATE TABLE IF NOT EXISTS analyses (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            repo_url TEXT NOT NULL,
            analyzed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            result JSONB NOT NULL
          );

          CREATE INDEX IF NOT EXISTS idx_analyses_repo_url ON analyses (repo_url);
          CREATE INDEX IF NOT EXISTS idx_analyses_analyzed_at ON analyses (analyzed_at);
        SQL
      ensure
        conn.close
      end
    end
  end
end
