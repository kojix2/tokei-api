require "ecr"
require "./base_context"

module Tokei::Api::Views::Contexts
  # エラーページ用コンテキスト
  class ErrorContext < BaseContext
    ECR.def_to_s "#{__DIR__}/../../views/error.ecr"
  end
end
