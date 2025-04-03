require "ecr"
require "./base_context"

module Tokei::Api::Views::Contexts
  # Context for API documentation page
  class ApiContext < BaseContext
    def initialize(error_message = nil)
      @error_message = error_message
    end

    ECR.def_to_s "#{__DIR__}/../../views/api.ecr"
  end
end
