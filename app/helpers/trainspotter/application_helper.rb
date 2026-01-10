module Trainspotter
  module ApplicationHelper
    def ansi_to_html(text)
      AnsiToHtml.convert(text)
    end
  end
end
