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

    def self.setup
      # SVG: debug/preview
      get "/og/github/:owner/:repo.svg" do |env|
        owner = env.params.url["owner"]
        repo = env.params.url["repo"]
        halt env, status_code: 400, response: "invalid owner" unless owner.matches?(SAFE)
        halt env, status_code: 400, response: "invalid repo" unless repo.matches?(SAFE)

        url = "https://github.com/#{owner}/#{repo}"
        begin
          json = Tokei::Api::Services::TokeiService.analyze_repo(url)
          svg = Tokei::Api::Services::OgImageService.generate_svg(owner, repo, json)
          env.response.content_type = "image/svg+xml; charset=utf-8"
          svg
        rescue ex
          env.response.status_code = 500
          "failed: #{ex.message}"
        end
      end

      # PNG: OGP main (cached)
      get "/og/github/:owner/:repo.png" do |env|
        owner = env.params.url["owner"]
        repo = env.params.url["repo"]
        halt env, status_code: 400, response: "invalid owner" unless owner.matches?(SAFE)
        halt env, status_code: 400, response: "invalid repo" unless repo.matches?(SAFE)

        cache = File.join(cache_dir, "#{owner}--#{repo}.png")
        if File.exists?(cache)
          mtime = File.info(cache).modification_time
          if (Time.utc - mtime) <= CACHE_TTL.seconds
            env.response.content_type = "image/png"
            env.response.headers["Cache-Control"] = "public, max-age=86400"
            next File.read(cache).to_slice
          end
        end

        url = "https://github.com/#{owner}/#{repo}"
        begin
          json = Tokei::Api::Services::TokeiService.analyze_repo(url)
          svg = Tokei::Api::Services::OgImageService.generate_svg(owner, repo, json)

          tmp_svg = File.join(Tokei::Api::Services::TokeiService::TEMP_DIR_BASE, "og-#{Random::Secure.hex(8)}.svg")
          tmp_png = File.join(Tokei::Api::Services::TokeiService::TEMP_DIR_BASE, "og-#{Random::Secure.hex(8)}.png")
          File.write(tmp_svg, svg)

          cmd = "#{rsvg_path} -w 1200 -h 630 \"#{tmp_svg}\" -o \"#{tmp_png}\""
          ok = system(cmd)
          unless ok && File.exists?(tmp_png) && File.size(tmp_png) > 0
            FileUtils.rm_rf(tmp_svg)
            FileUtils.rm_rf(tmp_png)
            halt env, status_code: 500, response: "failed to render png"
          end

          FileUtils.mkdir_p(File.dirname(cache)) unless Dir.exists?(File.dirname(cache))
          FileUtils.mv(tmp_png, cache)
          FileUtils.rm_rf(tmp_svg)

          env.response.content_type = "image/png"
          env.response.headers["Cache-Control"] = "public, max-age=86400"
          File.read(cache).to_slice
        rescue ex
          env.response.status_code = 500
          "failed: #{ex.message}"
        end
      end
    end
  end
end
