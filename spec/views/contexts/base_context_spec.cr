require "../../spec_helper"
require "../../../src/views/contexts/base_context"

private class TestBaseContext < Tokei::Api::Views::Contexts::BaseContext
end

private def with_env(name : String, value : String?, &)
  previous = ENV[name]?
  if value
    ENV[name] = value
  else
    ENV.delete(name)
  end

  yield
ensure
  if previous
    ENV[name] = previous
  else
    ENV.delete(name)
  end
end

describe Tokei::Api::Views::Contexts::BaseContext do
  describe "#server_base_url" do
    it "uses BASE_URL when configured" do
      with_env("BASE_URL", "https://tokei-api.example.com") do
        TestBaseContext.new.server_base_url.should eq("https://tokei-api.example.com")
      end
    end

    it "does not derive the public URL from HOST" do
      with_env("BASE_URL", nil) do
        with_env("HOST", "evil.example.com") do
          with_env("PORT", "4321") do
            TestBaseContext.new.server_base_url.should eq("http://localhost:4321")
          end
        end
      end
    end
  end
end
