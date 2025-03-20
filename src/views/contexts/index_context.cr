require "ecr"
require "./base_context"

module Tokei::Api::Views::Contexts
  # Context for index page
  class IndexContext < BaseContext
    def initialize(@error_message = nil)
      super(@error_message)
    end

    ECR.def_to_s "#{__DIR__}/../../views/index.ecr"
  end
end
