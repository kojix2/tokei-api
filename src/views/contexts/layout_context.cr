require "ecr"

module Tokei::Api::Views::Contexts
  # レイアウト用コンテキスト
  class LayoutContext
    property content : String
    property error_message : String?

    def initialize(@content, @error_message = nil)
    end

    ECR.def_to_s "#{__DIR__}/../../views/layout.ecr"
  end
end
