module Trainspotter
  class AnsiToHtml
    ANSI_CODES = {
      "0"  => "reset",
      "1"  => "bold",
      "2"  => "dim",
      "3"  => "italic",
      "4"  => "underline",
      "30" => "black",
      "31" => "red",
      "32" => "green",
      "33" => "yellow",
      "34" => "blue",
      "35" => "magenta",
      "36" => "cyan",
      "37" => "white",
      "90" => "bright-black",
      "91" => "bright-red",
      "92" => "bright-green",
      "93" => "bright-yellow",
      "94" => "bright-blue",
      "95" => "bright-magenta",
      "96" => "bright-cyan",
      "97" => "bright-white"
    }.freeze

    ANSI_PATTERN = /\e\[([0-9;]*)m/

    def self.convert(text)
      new.convert(text)
    end

    def convert(text)
      return "" if text.nil?

      result = []
      open_spans = 0
      current_classes = []

      parts = text.split(ANSI_PATTERN, -1)

      parts.each_with_index do |part, index|
        if index.odd?
          codes = part.split(";")
          new_classes = []

          codes.each do |code|
            if code == "0" || code == ""
              open_spans.times { result << "</span>" }
              open_spans = 0
              current_classes = []
            elsif ANSI_CODES[code]
              new_classes << "ansi-#{ANSI_CODES[code]}"
            end
          end

          if new_classes.any?
            result << "<span class=\"#{new_classes.join(" ")}\">"
            open_spans += 1
            current_classes = new_classes
          end
        else
          result << ERB::Util.html_escape(part)
        end
      end

      open_spans.times { result << "</span>" }

      result.join.html_safe
    end
  end
end
