require "json"
require "uuid"
require "../config/database"

module Tokei::Api::Models
  # リポジトリ解析結果を表すモデルクラス
  class Analysis
    property id : UUID?
    property repo_url : String
    property analyzed_at : Time?
    property result : JSON::Any

    def initialize(@repo_url : String, result : String | JSON::Any)
      @id = nil
      @analyzed_at = nil

      # 文字列の場合はJSONにパース、JSON::Anyの場合はそのまま使用
      @result = result.is_a?(String) ? JSON.parse(result) : result
    end

    # データベースに保存
    def save
      conn = Tokei::Api::Config::Database.connection
      begin
        if id.nil?
          # 新規作成
          conn.query(
            "INSERT INTO analyses (repo_url, result) VALUES ($1, $2) RETURNING id, analyzed_at",
            @repo_url, @result.to_json
          ) do |rs|
            if rs.move_next
              @id = rs.read(UUID)
              @analyzed_at = rs.read(Time)
            end
          end
        else
          # 更新
          conn.exec(
            "UPDATE analyses SET repo_url = $1, result = $2 WHERE id = $3",
            @repo_url, @result.to_json, @id.to_s
          )
        end
        true
      rescue ex
        puts "Error saving analysis: #{ex.message}"
        false
      ensure
        conn.close
      end
    end

    # リポジトリURLで検索
    def self.find_by_repo_url(repo_url : String) : Array(Analysis)
      conn = Tokei::Api::Config::Database.connection
      begin
        analyses = [] of Analysis
        conn.query("SELECT id, repo_url, analyzed_at, result FROM analyses WHERE repo_url = $1 ORDER BY analyzed_at DESC", repo_url) do |rs|
          rs.each do
            id_value = rs.read(UUID)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(JSON::Any)

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at
            analyses << analysis
          end
        end
        analyses
      ensure
        conn.close
      end
    end

    # IDで検索
    def self.find(id : String) : Analysis?
      conn = Tokei::Api::Config::Database.connection
      begin
        analysis = nil
        conn.query("SELECT id, repo_url, analyzed_at, result FROM analyses WHERE id = $1", id) do |rs|
          if rs.move_next
            id_value = rs.read(UUID)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(JSON::Any)

            analysis = Analysis.new(repo_url, result)
            analysis.id = id_value
            analysis.analyzed_at = analyzed_at
          end
        end
        analysis
      ensure
        conn.close
      end
    end
  end
end
