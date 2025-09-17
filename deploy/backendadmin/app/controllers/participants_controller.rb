class ParticipantsController < ApplicationController
  before_action :set_room
  before_action :set_participant, only: [:show, :remove, :mute_track, :update]
  
  def index
    @participants = LivekitService.list_participants(@room['name'])
  rescue => e
    @error = "Failed to fetch participants: #{e.message}"
    @participants = []
  end
  
  def show
    # Participant details are already loaded
  end
  
  def remove
    LivekitService.remove_participant(@room['name'], @participant['identity'])
    redirect_to room_path(@room['name']), notice: "Participant removed"
  rescue => e
    redirect_to room_path(@room['name']), alert: "Failed to remove participant: #{e.message}"
  end
  
  def mute_track
    LivekitService.mute_track(
      @room['name'],
      @participant['identity'],
      params[:track_sid],
      params[:muted] == 'true'
    )
    
    redirect_to room_path(@room['name']), notice: "Track #{params[:muted] == 'true' ? 'muted' : 'unmuted'}"
  rescue => e
    redirect_to room_path(@room['name']), alert: "Failed to mute/unmute track: #{e.message}"
  end
  
  def update
    LivekitService.update_participant(
      @room['name'],
      @participant['identity'],
      metadata: params[:metadata],
      permission: params[:permission]
    )
    
    redirect_to room_path(@room['name']), notice: "Participant updated"
  rescue => e
    redirect_to room_path(@room['name']), alert: "Failed to update participant: #{e.message}"
  end
  
  private
  
  def set_room
    @room = LivekitService.get_room(params[:room_id])
    redirect_to rooms_path, alert: "Room not found" unless @room
  end
  
  def set_participant
    @participant = LivekitService.get_participant(@room['name'], params[:id])
    redirect_to room_path(@room['name']), alert: "Participant not found" unless @participant
  end
end