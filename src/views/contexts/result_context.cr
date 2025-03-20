require "ecr"
require "./base_context"
require "../../models/analysis"
require "json"

module Tokei::Api::Views::Contexts
  # Context for results page
  class ResultContext < BaseContext
    property analysis : Tokei::Api::Models::Analysis
    property result_json : JSON::Any

    def initialize(@analysis, @result_json, @error_message = nil)
      super(@error_message)
    end

    ECR.def_to_s "#{__DIR__}/../../views/result.ecr"
  end
end
