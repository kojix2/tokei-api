require "spec"
require "../../src/services/security_block_handler"

class RecordingHandler
  include HTTP::Handler

  getter? called = false

  def call(context : HTTP::Server::Context)
    @called = true
    context.response.status_code = 204
  end
end

def handle_security_request(method : String, path : String)
  handler = Tokei::Api::Services::SecurityBlockHandler.new
  next_handler = RecordingHandler.new
  handler.next = next_handler

  io = IO::Memory.new
  request = HTTP::Request.new(method, path)
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)

  handler.call(context)
  response.close

  {context, io.to_s, next_handler}
end

def response_body(raw_response : String) : String
  raw_response.split("\r\n\r\n", 2)[1]? || ""
end

describe Tokei::Api::Services::SecurityBlockHandler do
  subject = Tokei::Api::Services::SecurityBlockHandler

  describe ".blocked_path?" do
    it "blocks PHP probes" do
      subject.blocked_path?("/shell.php").should be_true
      subject.blocked_path?("/wp-content/plugins/hellopress/wp_filemanager.php").should be_true
      subject.blocked_path?("/SHELL.PHP").should be_true
      subject.blocked_path?("/shell.php.txt").should be_true
      subject.blocked_path?("/index.phtml").should be_true
      subject.blocked_path?("/cgi-bin/test.cgi").should be_true
    end

    it "blocks sensitive framework and repository probes" do
      subject.blocked_path?("/.git/config").should be_true
      subject.blocked_path?("/.git-credentials").should be_true
      subject.blocked_path?("/.svn/entries").should be_true
      subject.blocked_path?("/.env").should be_true
      subject.blocked_path?("/actuator/env").should be_true
      subject.blocked_path?("/laravel/vendor/phpunit/phpunit/src/Util/PHP/eval-stdin.php").should be_true
      subject.blocked_path?("/node_modules/.vite/deps/foo.js").should be_true
      subject.blocked_path?("/WEB-INF/web.xml").should be_true
      subject.blocked_path?("/phpmyadmin").should be_true
      subject.blocked_path?("/adminer.php").should be_true
      subject.blocked_path?("/server-status").should be_true
      subject.blocked_path?("/wp-json/wp/v2/users").should be_true
    end

    it "blocks root-level config, logs, and backups" do
      subject.blocked_path?("/composer.json").should be_true
      subject.blocked_path?("/package-lock.json").should be_true
      subject.blocked_path?("/shard.lock").should be_true
      subject.blocked_path?("/backup.tar.gz").should be_true
      subject.blocked_path?("/database.sql").should be_true
      subject.blocked_path?("/access.log").should be_true
      subject.blocked_path?("/config.yml.bak").should be_true
    end

    it "blocks percent-encoded probes" do
      subject.blocked_path?("/%2eenv").should be_true
      subject.blocked_path?("/%2Eenv").should be_true
      subject.blocked_path?("/.git%2fconfig").should be_true
      subject.blocked_path?("/shell%2Ephp").should be_true
      subject.blocked_path?("/wp%2Dadmin/").should be_true
      subject.blocked_path?("/%252eenv").should be_true
    end

    it "handles malformed percent encodings without blocking or raising" do
      subject.blocked_path?("/%zz").should be_false
      subject.blocked_path?("/100%").should be_false
    end

    it "allows application routes and static assets" do
      subject.blocked_path?("/").should be_false
      subject.blocked_path?("/api/github/kojix2/tokei-api/languages").should be_false
      subject.blocked_path?("/badge/github/kojix2/tokei-api/lines").should be_false
      subject.blocked_path?("/badge/github/kojix2/memo.cr/lines").should be_false
      subject.blocked_path?("/badge/github/example/composer.json/lines").should be_false
      subject.blocked_path?("/badge/github/example/repo.php/lines").should be_false
      subject.blocked_path?("/api/github/example/repo.php/languages").should be_false
      subject.blocked_path?("/github/example/repo.php").should be_false
      subject.blocked_path?("/og/github/example/repo.php").should be_false
      subject.blocked_path?("/api/github/kojix2/node_modules/languages").should be_false
      subject.blocked_path?("/github/example/vendor").should be_false
      subject.blocked_path?("/badge/github/example/backup.sql/lines").should be_false
      subject.blocked_path?("/og/github/kojix2/tokei-api").should be_false
      subject.blocked_path?("/js/main.js").should be_false
      subject.blocked_path?("/css/style.css").should be_false
    end

    it "allows generic repository URL endpoints for non-GitHub hosts" do
      subject.blocked_path?("/analyze").should be_false
      subject.blocked_path?("/api/analyses").should be_false
      subject.blocked_path?("/api/badge/lines").should be_false
      subject.blocked_path?("/og").should be_false
    end
  end

  describe "#call" do
    it "returns a minimal 404 for blocked paths without calling the next handler" do
      context, raw_response, next_handler = handle_security_request("GET", "/.env")

      context.response.status_code.should eq(404)
      context.response.headers["Content-Type"].should eq("text/plain; charset=utf-8")
      context.response.headers["X-Content-Type-Options"].should eq("nosniff")
      response_body(raw_response).should eq("Not Found")
      next_handler.called?.should be_false
    end

    it "does not write a body for blocked HEAD requests" do
      context, raw_response, next_handler = handle_security_request("HEAD", "/.env")

      context.response.status_code.should eq(404)
      context.response.headers["Content-Type"].should eq("text/plain; charset=utf-8")
      context.response.headers["X-Content-Type-Options"].should eq("nosniff")
      response_body(raw_response).should be_empty
      next_handler.called?.should be_false
    end

    it "passes allowed paths to the next handler" do
      context, _raw_response, next_handler = handle_security_request("GET", "/api/analyses")

      context.response.status_code.should eq(204)
      next_handler.called?.should be_true
    end
  end
end
