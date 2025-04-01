require "spec"
require "../../src/services/tokei_service"

describe Tokei::Api::Services::TokeiService do
  describe ".valid_repo_url?" do
    it "validates GitHub HTTPS URLs" do
      # Basic GitHub HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/kojix2/tokei-api.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/kojix2/tokei-api").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/kojix2/tokei-api/").should be_true

      # URL with special characters in username or repository name
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/kojix2/tokei-api-db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/kojix2/tokei-api_db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/kojix2/tokei-api.db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/kojix2/tokei-api-db/").should be_true

      # Invalid GitHub URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/crystal-lang").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://github.com/").should be_false
    end

    it "validates GitHub SSH URLs" do
      # Basic GitHub SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:kojix2/tokei-api.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:kojix2/tokei-api").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:kojix2/tokei-api/").should be_true

      # URL with special characters in username or repository name
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:kojix2/tokei-api-db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:kojix2/tokei-api_db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:kojix2/tokei-api.db.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:kojix2/tokei-api-db/").should be_true

      # Invalid GitHub SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:crystal-lang").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@github.com:").should be_false
    end

    it "validates GitLab URLs" do
      # GitLab HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://gitlab.com/gitlab-org/gitlab.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://gitlab.com/gitlab-org/gitlab-ce.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://gitlab.com/gitlab-org/gitlab/").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://gitlab.com/gitlab-org/gitlab-ce/").should be_true

      # GitLab SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@gitlab.com:gitlab-org/gitlab.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@gitlab.com:gitlab-org/gitlab-ce.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@gitlab.com:gitlab-org/gitlab/").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@gitlab.com:gitlab-org/gitlab-ce/").should be_true
    end

    it "validates Bitbucket URLs" do
      # Bitbucket HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://bitbucket.org/atlassian/stash-example-plugin.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://bitbucket.org/atlassian/stash-example-plugin/").should be_true

      # Bitbucket SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@bitbucket.org:atlassian/stash-example-plugin.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@bitbucket.org:atlassian/stash-example-plugin/").should be_true
    end

    it "validates generic Git URLs" do
      # Generic HTTPS URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://git.example.com/user/repo.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://git.example.com/user/repo-name.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://git.example.com/user/repo/").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("https://git.example.com/user/repo-name/").should be_true

      # Generic SSH URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@git.example.com:user/repo.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@git.example.com:user/repo-name.git").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@git.example.com:user/repo/").should be_true
      Tokei::Api::Services::TokeiService.valid_repo_url?("git@git.example.com:user/repo-name/").should be_true
    end

    it "rejects invalid URLs" do
      # Completely invalid URL
      Tokei::Api::Services::TokeiService.valid_repo_url?("not a url").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("http://example.com").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("").should be_false

      # Invalid protocol
      Tokei::Api::Services::TokeiService.valid_repo_url?("http://github.com/kojix2/tokei-api.git").should be_false
      Tokei::Api::Services::TokeiService.valid_repo_url?("ftp://github.com/kojix2/tokei-api.git").should be_false
    end
  end
end
