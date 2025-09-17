class RoomsController < ApplicationController
  before_action :set_room, only: [:show, :destroy, :update_metadata]
  
  def index
    @rooms = LivekitService.list_rooms
  rescue => e
    @error = "Failed to fetch rooms: #{e.message}"
    @rooms = []
  end
  
  def show
    @participants = LivekitService.list_participants(@room['name'])
  rescue => e
    @error = "Failed to fetch room details: #{e.message}"
    @participants = []
  end
  
  def new
    @room = {}
  end
  
  def create
    room = LivekitService.create_room(
      name: params[:name],
      empty_timeout: params[:empty_timeout].to_i,
      max_participants: params[:max_participants].to_i,
      metadata: params[:metadata]
    )
    
    redirect_to rooms_path, notice: "Room '#{room['name']}' created successfully"
  rescue => e
    redirect_to new_room_path, alert: "Failed to create room: #{e.message}"
  end
  
  def destroy
    LivekitService.delete_room(@room['name'])
    redirect_to rooms_path, notice: "Room deleted successfully"
  rescue => e
    redirect_to rooms_path, alert: "Failed to delete room: #{e.message}"
  end
  
  def update_metadata
    LivekitService.update_room_metadata(@room['name'], params[:metadata])
    redirect_to room_path(@room['name']), notice: "Room metadata updated"
  rescue => e
    redirect_to room_path(@room['name']), alert: "Failed to update metadata: #{e.message}"
  end
  
  def generate_token
    token = LivekitService.create_access_token(
      room_name: params[:room_name],
      identity: params[:identity],
      name: params[:name],
      can_publish: params[:can_publish] != 'false',
      can_subscribe: params[:can_subscribe] != 'false'
    )
    
    render json: { 
      token: token,
      ws_url: LivekitService::WS_URL,
      join_url: "https://meet.livekit.io/?url=#{CGI.escape(LivekitService::WS_URL)}&token=#{token}"
    }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
  
  private
  
  def set_room
    @room = LivekitService.get_room(params[:id])
    redirect_to rooms_path, alert: "Room not found" unless @room
  end
end