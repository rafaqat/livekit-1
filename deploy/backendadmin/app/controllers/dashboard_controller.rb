class DashboardController < ApplicationController
  def index
    @server_info = LivekitService.server_info
    @recent_rooms = LivekitService.list_rooms.first(5)
  rescue => e
    @error = "Unable to connect to LiveKit server: #{e.message}"
  end
end