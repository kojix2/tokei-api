require "spec"
require "../../src/services/log_service"

describe Tokei::Api::Services::LogService do
  describe ".mask_url" do
    it "redacts HTTPS userinfo" do
      Tokei::Api::Services::LogService.mask_url("https://user:secret@example.com/owner/repo.git")
        .should eq("https://[redacted]@example.com/owner/repo.git")
    end

    it "leaves public repository URLs unchanged" do
      Tokei::Api::Services::LogService.mask_url("https://github.com/kojix2/tokei-api")
        .should eq("https://github.com/kojix2/tokei-api")
    end
  end

  describe ".exception_fields" do
    it "redacts HTTPS userinfo inside exception messages" do
      fields = Tokei::Api::Services::LogService.exception_fields(
        Exception.new("Invalid repository URL: https://user:secret@example.com/owner/repo.git")
      )

      fields["error_message"].should eq("Invalid repository URL: https://[redacted]@example.com/owner/repo.git")
    end
  end

  describe ".request_id" do
    it "generates a short hex request id" do
      Tokei::Api::Services::LogService.request_id.should match(/\A[0-9a-f]{8}\z/)
    end
  end
end
