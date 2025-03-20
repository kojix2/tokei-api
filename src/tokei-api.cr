require "kemal"
require "dotenv"
require "./config/database"
require "./models/analysis"
require "./controllers/api_controller"
require "./controllers/web_controller"

# tokei-api - Gitリポジトリのソースコードをtokeiコマンドで解析するAPI
module Tokei::Api
  VERSION = "0.1.0"

  # 環境変数を読み込む
  Dotenv.load

  # ポート設定
  @@port = ENV["PORT"]?.try(&.to_i) || 3000

  # データベースのセットアップ
  Config::Database.setup

  # コントローラーのセットアップ
  Controllers::ApiController.setup
  Controllers::WebController.setup

  # アプリケーションの起動
  def self.start
    puts "tokei-api サーバーを起動しています..."
    puts "ポート: #{@@port}"
    puts "環境: #{ENV["KEMAL_ENV"]? || "development"}"

    Kemal.run(port: @@port)
  end
end

# アプリケーションを起動
Tokei::Api.start
