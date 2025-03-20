require "spec"
require "../../src/services/tokei_service"

describe Tokei::Api::Services::TokeiService do
  describe ".valid_repo_url?" do
    it "validates GitHub HTTPS URLs" do
      # 基本的なGitHub HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/crystal-lang/crystal.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/crystal-lang/crystal").should be_true

      # ユーザー名やリポジトリ名に特殊文字を含むURL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/crystal-lang/crystal-db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/crystal-lang/crystal_db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/crystal-lang/crystal.db.git").should be_true

      # 無効なGitHub URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/crystal-lang").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/").should be_false
    end

    it "validates GitHub SSH URLs" do
      # 基本的なGitHub SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:crystal-lang/crystal.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:crystal-lang/crystal").should be_true

      # ユーザー名やリポジトリ名に特殊文字を含むURL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:crystal-lang/crystal-db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:crystal-lang/crystal_db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:crystal-lang/crystal.db.git").should be_true

      # 無効なGitHub SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:crystal-lang").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:").should be_false
    end

    it "validates GitLab URLs" do
      # GitLab HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://gitlab.com/gitlab-org/gitlab.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://gitlab.com/gitlab-org/gitlab-ce.git").should be_true

      # GitLab SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@gitlab.com:gitlab-org/gitlab.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@gitlab.com:gitlab-org/gitlab-ce.git").should be_true
    end

    it "validates Bitbucket URLs" do
      # Bitbucket HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://bitbucket.org/atlassian/stash-example-plugin.git").should be_true

      # Bitbucket SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@bitbucket.org:atlassian/stash-example-plugin.git").should be_true
    end

    it "validates generic Git URLs" do
      # Generic HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://git.example.com/user/repo.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://git.example.com/user/repo-name.git").should be_true

      # Generic SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@git.example.com:user/repo.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@git.example.com:user/repo-name.git").should be_true
    end

    it "rejects invalid URLs" do
      # 完全に無効なURL
      Tokei::Api::Services::TokeiService.valid_repo_url?("not a url").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("http://example.com").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("").should be_false

      # 不正なプロトコル
      Tokei::Api::Services::TokeiService.valid_repo_url?("http://github.com/crystal-lang/crystal.git").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("ftp://github.com/crystal-lang/crystal.git").should be_false
    end
  end
end
