require "json"

module Tokei::Api::Services
  class OgImageService
    PALETTE = %w[#4F46E5 #06B6D4 #22C55E #F59E0B #EF4444 #8B5CF6 #14B8A6 #EAB308]

    def self.top_languages(json_str : String, limit = 8) : Array(NamedTuple(name: String, code: Int64))
      langs = [] of NamedTuple(name: String, code: Int64)
      begin
        parsed = JSON.parse(json_str)
        parsed.as_h.each do |name, any|
          next if name == "Total"
          code = any["code"]?.try(&.as_i64?) || 0_i64
          langs << {name: name, code: code}
        end
      rescue
      end
      langs.sort_by! { |e| -e[:code] }
      langs[0, limit]
    end

    def self.escape_xml(s : String) : String
      s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;").gsub("'", "&apos;")
    end

    def self.generate_svg(owner : String, repo : String, data_json : String) : String
      title = "#{owner}/#{repo}"
      langs = top_languages(data_json)
      total = langs.sum(0_i64) { |e| e[:code] }.clamp(1_i64, Int64::MAX)

      w = 1200
      h = 630
      ml, mr, mt = 56, 56, 48
      head_h = 70
      graph_x = ml
      graph_y = mt + head_h + 24
      graph_w = w - ml - mr
      row_h = 46
      gap_y = 10
      bar_h = 26
      label_w = 260
      bar_w = graph_w - label_w - 20

      rows = String.build do |io|
        langs.each_with_index do |e, i|
          y = graph_y + i * (row_h + gap_y) + row_h // 2
          pct = (e[:code].to_f / total.to_f * 100.0)
          bw = (bar_w * pct / 100.0).round.to_i
          color = PALETTE[i % PALETTE.size]
          io << %(<text x="#{graph_x}" y="#{y}" font-size="24" fill="#E5E7EB" font-family="DejaVu Sans" dominant-baseline="middle">#{escape_xml(e[:name])}</text>)
          bx = graph_x + label_w + 20
          by = y - bar_h // 2
          io << %(<rect x="#{bx}" y="#{by}" width="#{bar_w}" height="#{bar_h}" rx="13" ry="13" fill="#0F172A" stroke="#1F2937"/>)
          io << %(<rect x="#{bx}" y="#{by}" width="#{bw}" height="#{bar_h}" rx="13" ry="13" fill="#{color}"/>)
        end
        if langs.empty?
          io << %(<text x="#{graph_x}" y="#{graph_y}" font-size="22" fill="#9CA3AF" font-family="DejaVu Sans">No data</text>)
        end
      end

      <<-SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{w}" height="#{h}">
        <rect width="100%" height="100%" fill="#0B1020"/>
        <text x="#{ml}" y="#{mt}" font-size="44" font-weight="700" fill="#F3F4F6" font-family="DejaVu Sans" dominant-baseline="hanging">#{escape_xml(title)}</text>
        #{rows}
      </svg>
      SVG
    end
  end
end
