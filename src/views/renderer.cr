require "./contexts/index_context"
require "./contexts/result_context"
require "./contexts/error_context"
require "./contexts/layout_context"

module Tokei::Api::Views
  # Rendering helper
  module Renderer
    def self.render_with_layout(content_context, error_message = nil)
      content = content_context.to_s
      Contexts::LayoutContext.new(content, error_message).to_s
    end

    def self.render_index(error_message = nil)
      index_context = Contexts::IndexContext.new(error_message)
      render_with_layout(index_context, error_message)
    end

    def self.render_result(analysis, result_json, error_message = nil)
      result_context = Contexts::ResultContext.new(analysis, result_json, error_message)
      render_with_layout(result_context, error_message)
    end

    def self.render_error(error_message = nil)
      error_context = Contexts::ErrorContext.new(error_message)
      render_with_layout(error_context, error_message)
    end
  end
end
