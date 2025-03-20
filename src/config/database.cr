require "pg"
require "dotenv"

module Tokei::Api::Config
  # データベース接続を管理するモジュール
  module Database
    # 環境変数を読み込む
    Dotenv.load

    # データベースプロバイダー（local または neon）
    DATABASE_PROVIDER = ENV["DATABASE_PROVIDER"]? || "local"

    # データベース接続URL
    DATABASE_URL = ENV["DATABASE_URL"]? || "postgresql://localhost/tokei-api"

    # データベース接続を取得する
    def self.connection
      # 接続オプションを設定
      conn_options = "#{DATABASE_URL}"

      # Neonの場合はSSLモードを追加
      if DATABASE_PROVIDER == "neon" && !conn_options.includes?("sslmode=")
        # URLパラメータとして正しく追加
        if conn_options.includes?("?")
          conn_options += "&sslmode=require"
        else
          conn_options += "?sslmode=require"
        end
      end

      # 接続を試行
      begin
        PG.connect(conn_options)
      rescue ex
        puts "データベース接続エラー: #{ex.message}"
        puts "接続先: #{DATABASE_PROVIDER} (#{DATABASE_URL})"
        raise ex
      end
    end

    # データベースの初期化（テーブル作成など）
    def self.setup
      puts "データベース初期化中... (プロバイダー: #{DATABASE_PROVIDER})"

      conn = connection
      begin
        # analysesテーブルが存在しない場合は作成（SQLコマンドを分割して実行）
        conn.exec "CREATE TABLE IF NOT EXISTS analyses (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          repo_url TEXT NOT NULL,
          analyzed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          result JSONB NOT NULL
        );"

        # インデックスを作成
        conn.exec "CREATE INDEX IF NOT EXISTS idx_analyses_repo_url ON analyses (repo_url);"
        conn.exec "CREATE INDEX IF NOT EXISTS idx_analyses_analyzed_at ON analyses (analyzed_at);"

        puts "データベース初期化完了"
      rescue ex
        puts "データベース初期化エラー: #{ex.message}"
        raise ex
      ensure
        conn.close
      end
    end
  end
end
