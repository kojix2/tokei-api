require "kemal"
require "../services/tokei_service"
require "../services/og_image_service"

module Tokei::Api::Controllers
  class OgController
    CACHE_TTL = (ENV["OG_CACHE_TTL_SECONDS"]? || "21600").to_i64 # 6 hours
    SAFE      = /^[A-Za-z0-9._-]+$/

    def self.cache_dir : String
      base = Tokei::Api::Services::TokeiService::TEMP_DIR_BASE
      dir = File.join(base, "og-cache")
      Dir.exists?(dir) ? dir : (FileUtils.mkdir_p(dir); dir)
    end

    def self.rsvg_path : String
      return ENV["RSVG_CONVERT_PATH"] if ENV["RSVG_CONVERT_PATH"]?
      status = Process.run("which", {"rsvg-convert"}, output: Process::Redirect::Close, error: Process::Redirect::Close)
      raise "rsvg-convert not found. Install librsvg." unless status.success?
      "rsvg-convert"
    end

    # Content negotiation helper: query param > Accept header > default png
    def self.wants_svg?(env : HTTP::Server::Context) : Bool
      fmt = env.params.query["format"]?
      return true if fmt && fmt.downcase == "svg"
      return false if fmt && fmt.downcase == "png"
      accept = env.request.headers["Accept"]?
      !!(accept && accept.includes?("image/svg+xml"))
    end

    private def self.sanitize_cache_key(s : String) : String
      s.gsub(/[^A-Za-z0-9._-]+/, "_")
    end

    private def self.serve_og(env : HTTP::Server::Context, cache_key : String, owner : String, repo : String, repo_url : String)
      json = Tokei::Api::Services::TokeiService.analyze_repo(repo_url)
      svg = Tokei::Api::Services::OgImageService.generate_svg(owner, repo, json)

      if wants_svg?(env)
        env.response.content_type = "image/svg+xml; charset=utf-8"
        return svg
      end

      cache = File.join(cache_dir, "#{cache_key}.png")
      if File.exists?(cache)
        mtime = File.info(cache).modification_time
        if (Time.utc - mtime) <= CACHE_TTL.seconds
          env.response.content_type = "image/png"
          env.response.headers["Cache-Control"] = "public, max-age=86400"
          return File.open(cache, "rb") { |f| f.getb_to_end }
        end
      end

      tmp_svg = File.join(Tokei::Api::Services::TokeiService::TEMP_DIR_BASE, "og-#{Random::Secure.hex(8)}.svg")
      tmp_png = File.join(Tokei::Api::Services::TokeiService::TEMP_DIR_BASE, "og-#{Random::Secure.hex(8)}.png")
      File.write(tmp_svg, svg)

      result = Process.run(rsvg_path, ["-w", "1200", "-h", "630", tmp_svg, "-o", tmp_png],
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit)

      unless result.success? && File.exists?(tmp_png) && File.size(tmp_png) > 0
        FileUtils.rm_rf(tmp_svg)
        FileUtils.rm_rf(tmp_png)
        env.response.status_code = 500
        return "failed to render png"
      end
      
      FileUtils.mkdir_p(File.dirname(cache)) unless Dir.exists?(File.dirname(cache))
      FileUtils.mv(tmp_png, cache)
      FileUtils.rm_rf(tmp_svg)

      env.response.content_type = "image/png"
      env.response.headers["Cache-Control"] = "public, max-age=86400"
      File.open(cache, "rb") { |f| f.getb_to_end }
    end

    def self.setup
      # Unified GitHub route (no extension)
      get "/og/github/:owner/:repo" do |env|
        owner = env.params.url["owner"]
        repo = env.params.url["repo"]
        halt env, status_code: 400, response: "invalid owner" unless owner.matches?(SAFE)
        halt env, status_code: 400, response: "invalid repo" unless repo.matches?(SAFE)
        url = "https://github.com/#{owner}/#{repo}"
        serve_og(env, "#{owner}--#{repo}", owner, repo, url)
      end

      # Generic route by repo URL (?url=...)
      get "/og" do |env|
        repo_url = env.params.query["url"]?
        unless repo_url && Tokei::Api::Services::TokeiService.valid_repo_url?(repo_url)
          env.response.status_code = 400
          next "invalid url"
        end
        owner_repo = Tokei::Api::Services::TokeiService.extract_github_info(repo_url)
        owner = owner_repo ? owner_repo[0] : "repo"
        repo = owner_repo ? owner_repo[1] : "analysis"
        cache_key = sanitize_cache_key(repo_url)
        serve_og(env, cache_key, owner, repo, repo_url)
      end
    end
  end
end
