require "ecr"

module Tokei::Api::Views::Contexts
  # Context for layout
  class LayoutContext
    property content : String
    property error_message : String?
    property meta_tags : String?

    def initialize(@content, @error_message = nil, @meta_tags : String? = nil)
    end

    ECR.def_to_s "#{__DIR__}/../../views/layout.ecr"
  end
end
