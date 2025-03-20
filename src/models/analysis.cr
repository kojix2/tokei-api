require "json"
require "uuid"
require "../config/database"

module Tokei::Api::Models
  # リポジトリ解析結果を表すモデルクラス
  class Analysis
    property id : UUID?
    property repo_url : String
    property analyzed_at : Time?
    property result : String

    def initialize(@repo_url : String, @result : String)
      @id = nil
      @analyzed_at = nil
    end

    # データベースに保存
    def save
      conn = Tokei::Api::Config::Database.connection
      begin
        if id.nil?
          # 新規作成
          conn.query(
            "INSERT INTO analyses (repo_url, result) VALUES ($1, $2) RETURNING id, analyzed_at",
            @repo_url, @result
          ) do |rs|
            if rs.move_next
              @id = UUID.new(rs.read(String))
              @analyzed_at = rs.read(Time)
            end
          end
        else
          # 更新
          conn.exec(
            "UPDATE analyses SET repo_url = $1, result = $2 WHERE id = $3",
            @repo_url, @result, @id.to_s
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
            id = rs.read(String)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(String)

            analysis = Analysis.new(repo_url, result)
            analysis.id = UUID.new(id)
            analysis.analyzed_at = analyzed_at
            analyses << analysis
          end
        end
        analyses
      ensure
        conn.close
      end
    end

    # 最近の解析結果を取得
    def self.list_recent(limit : Int32 = 10) : Array(Analysis)
      conn = Tokei::Api::Config::Database.connection
      begin
        analyses = [] of Analysis
        conn.query("SELECT id, repo_url, analyzed_at, result FROM analyses ORDER BY analyzed_at DESC LIMIT $1", limit) do |rs|
          rs.each do
            id = rs.read(String)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(String)

            analysis = Analysis.new(repo_url, result)
            analysis.id = UUID.new(id)
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
            id = rs.read(String)
            repo_url = rs.read(String)
            analyzed_at = rs.read(Time)
            result = rs.read(String)

            analysis = Analysis.new(repo_url, result)
            analysis.id = UUID.new(id)
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
