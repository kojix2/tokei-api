require "json"

module Tokei::Api::Services
  # Shared: extract language statistics from tokei JSON result
  module LanguageStatsService
    # Basic stats (files/code/comments/blanks)
    # { "Lang" => {"files"=>Int32, "code"=>Int32, "comments"=>Int32, "blanks"=>Int32} }
    def self.extract_basic(result : JSON::Any) : Hash(String, Hash(String, Int32))
      languages = {} of String => Hash(String, Int32)

      result.as_h.each do |language, stats|
        next if language == "Total"
        stats_obj = stats.as_h

        files = stats_obj["reports"]?.try(&.as_a.size) || stats_obj["files"]?.try(&.as_i) || 0
        code = stats_obj["code"]?.try(&.as_i) || 0
        comments = stats_obj["comments"]?.try(&.as_i) || 0
        blanks = stats_obj["blanks"]?.try(&.as_i) || 0

        languages[language.to_s] = {
          "files"    => files.to_i,
          "code"     => code.to_i,
          "comments" => comments.to_i,
          "blanks"   => blanks.to_i,
        }
      end

      languages
    end

    # Basic stats + percentage (%)
    # { "Lang" => {"files"=>Int32, "code"=>Int32, "comments"=>Int32, "blanks"=>Int32, "percentage"=>Float64} }
    def self.extract_with_percentage(result : JSON::Any) : Hash(String, Hash(String, Int32 | Float64))
      languages = {} of String => Hash(String, Int32 | Float64)

      # Sum total code lines
      total_code = 0
      result.as_h.each do |language, stats|
        next if language == "Total"
        code = stats.as_h["code"]?.try(&.as_i) || 0
        total_code += code.to_i
      end

      # Details + composition ratio
      result.as_h.each do |language, stats|
        next if language == "Total"
        stats_obj = stats.as_h

        files = stats_obj["reports"]?.try(&.as_a.size) || stats_obj["files"]?.try(&.as_i) || 0
        code = stats_obj["code"]?.try(&.as_i) || 0
        comments = stats_obj["comments"]?.try(&.as_i) || 0
        blanks = stats_obj["blanks"]?.try(&.as_i) || 0

        percentage = total_code > 0 ? (code.to_i.to_f / total_code.to_f * 100).round(1) : 0.0

        languages[language.to_s] = {
          "files"      => files.to_i,
          "code"       => code.to_i,
          "comments"   => comments.to_i,
          "blanks"     => blanks.to_i,
          "percentage" => percentage,
        }
      end

      languages
    end
  end
end
