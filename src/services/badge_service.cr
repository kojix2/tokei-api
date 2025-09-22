module Tokei::Api::Services
  # Shared: badge data generation
  module BadgeService
    # Format e.g. 1200 -> "1.2k"
    def self.format_number(num : Int32) : String
      if num >= 1_000_000
        "%.1fM" % (num / 1_000_000.0)
      elsif num >= 1_000
        "%.1fk" % (num / 1_000.0)
      else
        num.to_s
      end
    end

    # Generate badge JSON (shields.io compatible)
    def self.generate(badge_type : String, analysis) : NamedTuple(schemaVersion: Int32, label: String, message: String, color: String)
      case badge_type
      when "lines"
        {schemaVersion: 1, label: "Lines of Code", message: format_number(analysis.total_lines || 0), color: "blue"}
      when "language"
        {schemaVersion: 1, label: "Top Language", message: (analysis.top_language || "Unknown"), color: "brightgreen"}
      when "languages"
        {schemaVersion: 1, label: "Languages", message: (analysis.language_count || 0).to_s, color: "orange"}
      when "ratio"
        ratio = analysis.code_comment_ratio || 0.0
        {schemaVersion: 1, label: "Code to Comment", message: "#{ratio.round(1)}:1", color: "blueviolet"}
      else
        raise "Invalid badge type: #{badge_type}"
      end
    end
  end
end
