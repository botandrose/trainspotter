module Trainspotter
  class ApplicationController < ActionController::Base
    before_action :ensure_trainspotter_connected

    private

    def ensure_trainspotter_connected
      Record.ensure_connected
    end
  end
end
