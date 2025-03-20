require "json"
require "file_utils"
require "random"
require "dotenv"

module Tokei::Api::Services
  # tokeiコマンドを実行するサービスクラス
  class TokeiService
    # 環境変数を読み込む
    Dotenv.load

    # 一時ディレクトリのベースパス
    TEMP_DIR_BASE = ENV["TEMP_DIR"]? || "/tmp/tokei-api"

    # リポジトリURLのバリデーション
    def self.valid_repo_url?(url : String) : Bool
      # GitHubのHTTPSまたはSSH URLのパターン
      github_https = /^https:\/\/github\.com\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      github_ssh = /^git@github\.com:[\w.-]+\/[\w.-]+(?:\.git)?$/

      # GitLabのHTTPSまたはSSH URLのパターン
      gitlab_https = /^https:\/\/gitlab\.com\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      gitlab_ssh = /^git@gitlab\.com:[\w.-]+\/[\w.-]+(?:\.git)?$/

      # BitbucketのHTTPSまたはSSH URLのパターン
      bitbucket_https = /^https:\/\/bitbucket\.org\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      bitbucket_ssh = /^git@bitbucket\.org:[\w.-]+\/[\w.-]+(?:\.git)?$/

      # 一般的なgit URLのパターン
      generic_https = /^https:\/\/[\w.-]+\.[\w.-]+\/[\w.-]+\/[\w.-]+(?:\.git)?$/
      generic_ssh = /^git@[\w.-]+\.[\w.-]+:[\w.-]+\/[\w.-]+(?:\.git)?$/

      !!(url.match(github_https) || url.match(github_ssh) ||
        url.match(gitlab_https) || url.match(gitlab_ssh) ||
        url.match(bitbucket_https) || url.match(bitbucket_ssh) ||
        url.match(generic_https) || url.match(generic_ssh))
    end

    # リポジトリを解析
    def self.analyze_repo(repo_url : String) : String
      # URLのバリデーション
      raise "Invalid repository URL: #{repo_url}" unless valid_repo_url?(repo_url)

      # 一時ディレクトリの作成
      random_suffix = Random::Secure.hex(8)
      temp_dir = File.join(TEMP_DIR_BASE, random_suffix)

      begin
        # ディレクトリが存在しない場合は作成
        FileUtils.mkdir_p(TEMP_DIR_BASE) unless Dir.exists?(TEMP_DIR_BASE)

        # リポジトリのクローン
        clone_command = "git clone --depth 1 #{repo_url} #{temp_dir}"
        clone_result = system(clone_command)

        unless clone_result
          raise "Failed to clone repository: #{repo_url}"
        end

        # tokeiコマンドの実行
        tokei_command = "cd #{temp_dir} && tokei --output json"
        output = `#{tokei_command}`

        if output.empty?
          raise "Failed to analyze repository with tokei"
        end

        return output
      ensure
        # 一時ディレクトリの削除
        FileUtils.rm_rf(temp_dir) if Dir.exists?(temp_dir)
      end
    end
  end
end
