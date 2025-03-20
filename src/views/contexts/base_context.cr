require "socket"

module Tokei::Api::Views::Contexts
  # 基本コンテキストクラス
  abstract class BaseContext
    property error_message : String?

    def initialize(@error_message = nil)
    end

    # サーバーのホスト名またはIPアドレスを取得
    def server_host : String
      # 環境変数からホストを取得（設定されている場合）
      env_host = ENV["HOST"]?
      return env_host if env_host && !env_host.empty?

      # `hostname -I` コマンドを実行してIPアドレスを取得
      begin
      ip_address = `hostname -I`.strip.split.first
      return ip_address unless ip_address.empty?
      rescue
      # エラーが発生した場合はlocalhostを返す
      end

      # デフォルトはlocalhost
      "localhost"
    end

    # サーバーのポート番号を取得
    def server_port : Int32
      ENV["PORT"]?.try(&.to_i) || 3000
    end

    # サーバーのベースURLを取得
    def server_base_url : String
      ENV["BASE_URL"]? || "http://#{server_host}:#{server_port}"
    end
  end
end
