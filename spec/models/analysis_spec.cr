require "spec"

ENV["CACHE_DB_PATH"] = "/tmp/tokei-api-analysis-spec.sqlite3"

require "../../src/config/database"
require "../../src/models/analysis"

private DB_FILES = [
  ENV["CACHE_DB_PATH"],
  "#{ENV["CACHE_DB_PATH"]}-wal",
  "#{ENV["CACHE_DB_PATH"]}-shm",
]

private def reset_cache_db
  DB_FILES.each do |path|
    File.delete(path) if File.exists?(path)
  end

  Tokei::Api::Config::Database.setup
end

private def sample_result_json
  {
    "Crystal" => {
      "blanks"   => 2,
      "comments" => 3,
      "code"     => 10,
    },
    "Total" => {
      "blanks"   => 2,
      "comments" => 3,
      "code"     => 10,
    },
  }.to_json
end

describe Tokei::Api::Models::Analysis do
  before_each do
    reset_cache_db
  end

  after_all do
    DB_FILES.each do |path|
      File.delete(path) if File.exists?(path)
    end
  end

  it "saves and finds an analysis by id" do
    analysis = Tokei::Api::Models::Analysis.new("https://github.com/kojix2/tokei-api", sample_result_json)

    analysis.save.should be_true
    analysis.id.should_not be_nil
    analysis.analyzed_at.should_not be_nil

    if found = Tokei::Api::Models::Analysis.find(analysis.id.to_s)
      found.repo_url.should eq("https://github.com/kojix2/tokei-api")
      found.total_code.should eq(10)
      found.total_comments.should eq(3)
      found.top_language.should eq("Crystal")
    else
      fail "Expected analysis to be found"
    end
  end

  it "finds the latest summary for a repository without loading the result" do
    analysis = Tokei::Api::Models::Analysis.new("https://github.com/kojix2/tokei-api", sample_result_json)
    analysis.save.should be_true

    if found = Tokei::Api::Models::Analysis.find_latest_by_repo_url("https://github.com/kojix2/tokei-api")
      found.id.should eq(analysis.id)
      found.result.as_h.empty?.should be_true
      found.total_lines.should eq(15)
    else
      fail "Expected latest analysis to be found"
    end
  end

  it "cleans up expired cache rows" do
    analysis = Tokei::Api::Models::Analysis.new("https://github.com/kojix2/tokei-api", sample_result_json)
    analysis.save.should be_true

    conn = Tokei::Api::Config::Database.connection
    begin
      conn.exec(
        "UPDATE analyses SET analyzed_at = ? WHERE id = ?",
        Tokei::Api::Models::Analysis.timestamp(Time.utc - 8.days),
        analysis.id.to_s
      )
    ensure
      conn.close
    end

    Tokei::Api::Models::Analysis.cleanup_old_data.should eq(1)
    Tokei::Api::Models::Analysis.find(analysis.id.to_s).should be_nil
  end
end
