class RecordingsController < ApplicationController
  def index
    @egresses = LivekitService.list_egress
    @ingresses = LivekitService.list_ingress
  rescue => e
    @error = e.message
    @egresses = []
    @ingresses = []
  end
  
  def new_egress
    @rooms = LivekitService.list_rooms
    @room_name = params[:room_name]
  end
  
  def create_egress
    result = case params[:egress_type]
    when 'room_composite'
      LivekitService.start_room_composite_egress(
        room_name: params[:room_name],
        file_outputs: build_file_output,
        stream_outputs: build_stream_outputs,
        layout: params[:layout] || 'speaker-dark',
        audio_only: params[:audio_only] == 'true'
      )
    when 'track_composite'
      LivekitService.start_track_composite_egress(
        room_name: params[:room_name],
        audio_track_id: params[:audio_track_id],
        video_track_id: params[:video_track_id],
        file_outputs: build_file_output,
        stream_outputs: build_stream_outputs
      )
    when 'track'
      LivekitService.start_track_egress(
        room_name: params[:room_name],
        track_id: params[:track_id],
        file_output: build_file_output,
        stream_output: build_stream_output
      )
    end
    
    redirect_to recordings_path, notice: "Recording started successfully"
  rescue => e
    redirect_to recordings_path, alert: "Failed to start recording: #{e.message}"
  end
  
  def stop_egress
    LivekitService.stop_egress(params[:id])
    redirect_to recordings_path, notice: "Recording stopped successfully"
  rescue => e
    redirect_to recordings_path, alert: "Failed to stop recording: #{e.message}"
  end
  
  def update_layout
    LivekitService.update_layout(params[:id], params[:layout])
    redirect_to recordings_path, notice: "Layout updated successfully"
  rescue => e
    redirect_to recordings_path, alert: "Failed to update layout: #{e.message}"
  end
  
  def new_ingress
    @rooms = LivekitService.list_rooms
  end
  
  def create_ingress
    result = LivekitService.create_ingress(
      name: params[:name],
      room_name: params[:room_name],
      participant_identity: params[:participant_identity],
      participant_name: params[:participant_name],
      stream_key: params[:stream_key],
      input_type: params[:input_type] || 'RTMP_INPUT'
    )
    
    redirect_to recordings_path, notice: "Ingress created successfully. Stream URL: #{result['url']}, Stream Key: #{result['streamKey']}"
  rescue => e
    redirect_to recordings_path, alert: "Failed to create ingress: #{e.message}"
  end
  
  def delete_ingress
    LivekitService.delete_ingress(params[:id])
    redirect_to recordings_path, notice: "Ingress deleted successfully"
  rescue => e
    redirect_to recordings_path, alert: "Failed to delete ingress: #{e.message}"
  end
  
  private
  
  def build_file_output
    return nil unless params[:output_type] == 'file'
    
    {
      filepath: params[:filepath] || "/recordings/#{Time.now.to_i}.mp4",
      output: {
        case: 'file',
        value: {
          filepath: params[:filepath] || "/recordings/#{Time.now.to_i}.mp4"
        }
      }
    }
  end
  
  def build_stream_outputs
    return nil unless params[:output_type] == 'stream' && params[:stream_urls].present?
    
    params[:stream_urls].split(',').map do |url|
      {
        protocol: 'rtmp',
        urls: [url.strip]
      }
    end
  end
  
  def build_stream_output
    return nil unless params[:output_type] == 'stream' && params[:stream_url].present?
    
    {
      protocol: 'rtmp',
      urls: [params[:stream_url]]
    }
  end
end