module Trainspotter
  module ApplicationHelper
    include Trainspotter.isolated_assets_helper

    def ansi_to_html(text)
      AnsiToHtml.convert(text)
    end
  end
end
