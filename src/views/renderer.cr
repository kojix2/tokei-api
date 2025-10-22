require "./contexts/index_context"
require "./contexts/result_context"
require "./contexts/error_context"
require "./contexts/layout_context"
require "./contexts/api_context"
require "./contexts/badges_context"

module Tokei::Api::Views
  # Rendering helper
  module Renderer
    def self.render_with_layout(content_context, error_message = nil, meta_tags : String? = nil)
      content = content_context.to_s
      Contexts::LayoutContext.new(content, error_message, meta_tags).to_s
    end

    def self.render_index(error_message = nil)
      index_context = Contexts::IndexContext.new(error_message)
      render_with_layout(index_context, error_message)
    end

    def self.render_result(analysis, result_json, error_message = nil)
      result_context = Contexts::ResultContext.new(analysis, result_json, error_message)

      # Build OG/Twitter meta tags for social preview
      base = result_context.server_base_url
      # point to lightweight SVG->PNG route (GitHub style if possible)
      og_image = if result_context.is_github_repo? && (info = result_context.github_info)
                   owner, repo = info
                   "#{base}/og/github/#{owner}/#{repo}.png"
                 else
                   # fallback: still point to analysis-based PNG if later implemented; for now use GitHub route if applicable only
                   "#{base}/og/github/preview.png"
                 end
      og_url = "#{base}/analyses/#{analysis.id}"

      title = if result_context.is_github_repo? && (info = result_context.github_info)
                owner, repo = info
                "#{owner}/#{repo} - Language Breakdown"
              else
                "tokei-api: Language Breakdown"
              end

      desc = "Programming languages by tokei (lines of code)."

      meta_tags = String.build do |io|
        io << %(<meta property="og:type" content="website">)
        io << %(<meta property="og:site_name" content="tokei-api">)
        io << %(<meta property="og:title" content="#{title}">)
        io << %(<meta property="og:description" content="#{desc}">)
        io << %(<meta property="og:image" content="#{og_image}">)
        io << %(<meta property="og:image:width" content="1200">)
        io << %(<meta property="og:image:height" content="630">)
        io << %(<meta property="og:url" content="#{og_url}">)
        io << %(<meta name="twitter:card" content="summary_large_image">)
        io << %(<meta name="twitter:title" content="#{title}">)
        io << %(<meta name="twitter:description" content="#{desc}">)
        io << %(<meta name="twitter:image" content="#{og_image}">)
      end

      render_with_layout(result_context, error_message, meta_tags)
    end

    def self.render_error(error_message = nil)
      error_context = Contexts::ErrorContext.new(error_message)
      render_with_layout(error_context, error_message)
    end

    def self.render_api(error_message = nil)
      api_context = Contexts::ApiContext.new(error_message)
      render_with_layout(api_context, error_message)
    end

    def self.render_badges(error_message = nil)
      badges_context = Contexts::BadgesContext.new(error_message)
      render_with_layout(badges_context, error_message)
    end
  end
end
