class VideosController < ApplicationController
  def index
    @videos = Video.recent
  end
  
  def new
    @video = Video.new
  end
  
  def create
    if params[:file].present?
      uploaded_file = params[:file]
      video_id = "video_#{SecureRandom.hex(8)}"
      ext = File.extname(uploaded_file.original_filename).presence || '.mp4'
      filename = "#{video_id}#{ext}"
      
      # Create directory if it doesn't exist
      video_dir = Rails.root.join('public', 'videos')
      FileUtils.mkdir_p(video_dir)
      
      # Save uploaded file
      video_path = video_dir.join(filename)
      File.open(video_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end
      
      # Room name for potential future use (live broadcast mode)
      room_name = "video-#{video_id}"
      
      # Only create LiveKit room if explicitly requested for live broadcast mode
      # VOD (on_demand) mode doesn't need LiveKit rooms
      
      # Create video record in database
      base_url = ENV['ASSET_BASE_URL'].presence || request.base_url
      @video = Video.create!(
        video_id: video_id,
        title: params[:title].presence || uploaded_file.original_filename,
        description: params[:description],
        original_filename: uploaded_file.original_filename,
        file_size: uploaded_file.size,
        file_extension: ext.delete('.'),
        room_name: room_name,
        video_url: "#{base_url}/videos/#{filename}",
        uploaded_at: Time.current
      )
      
      # Trigger HLS transcoding in background
      # TODO: Fix job after upload is working
      # VideoTranscodeJob.perform_later(@video.video_id)
      
      redirect_to videos_path, notice: "Video uploaded successfully. Video ID: #{video_id}."
    else
      redirect_to new_video_path, alert: "Please select a video file to upload"
    end
  rescue => e
    redirect_to videos_path, alert: "Upload failed: #{e.message}"
  end
  
  def show
    @video = Video.find_by!(video_id: params[:id])
    
    # Generate viewer token for testing
    @viewer_token = generate_viewer_token(@video.video_id)
    @publisher_token = generate_publisher_token(@video.video_id)
  end
  
  def destroy
    @video = Video.find_by!(video_id: params[:id])
    
    # Delete video file
    if @video.file_exists?
      File.delete(@video.file_path)
    end
    
    # Delete HLS files if they exist
    hls_dir = Rails.root.join('public', 'videos', 'hls', @video.video_id)
    FileUtils.rm_rf(hls_dir) if Dir.exist?(hls_dir)
    
    # Stop streaming if active
    if @video.streaming_active && @video.ingress_id
      LivekitService.delete_ingress(@video.ingress_id) rescue nil
    end
    
    # Delete room
    begin
      LivekitService.delete_room(@video.room_name)
    rescue => e
      Rails.logger.error "Failed to delete room: #{e.message}"
    end
    
    # Delete database record
    @video.destroy
    
    redirect_to videos_path, notice: "Video deleted successfully"
  end
  
  def hls_player
    @video = Video.find_by!(video_id: params[:id])
  end
  
  def play
    @video = Video.find_by!(video_id: params[:id])
    
    # Start streaming if not already active
    unless @video.streaming_active
      start_streaming_for_video(@video)
      @video.reload
    end
    
    # Generate viewer token
    token = generate_viewer_token(@video.video_id)
    
    render json: {
      room_name: @video.room_name,
      token: token,
      websocket_url: ENV['LIVEKIT_WS_URL'] || 'wss://livekit.lovedrop.live',
      video_id: @video.video_id,
      ingress_id: @video.ingress_id,
      streaming_status: @video.streaming_status
    }
  end
  
  def publish
    @video = Video.find_by!(video_id: params[:id])
    
    # Generate publisher token for testing
    token = generate_publisher_token(@video.video_id)
    
    render json: {
      room_name: @video.room_name,
      token: token,
      websocket_url: ENV['LIVEKIT_WS_URL'] || 'wss://livekit.lovedrop.live'
    }
  end
  
  def start_stream
    @video = Video.find_by!(video_id: params[:id])
    
    if @video.streaming_active
      render json: { message: "Stream already active", ingress_id: @video.ingress_id }
    else
      start_streaming_for_video(@video)
      @video.reload
      render json: { 
        message: "Stream started", 
        ingress_id: @video.ingress_id,
        status: @video.streaming_status
      }
    end
  rescue => e
    render json: { error: e.message }, status: 500
  end
  
  def stop_stream
    @video = Video.find_by!(video_id: params[:id])
    
    if @video.streaming_active && @video.ingress_id
      LivekitService.delete_ingress(@video.ingress_id)
      @video.stop_streaming!
      render json: { message: "Stream stopped" }
    else
      render json: { message: "No active stream" }
    end
  rescue => e
    render json: { error: e.message }, status: 500
  end
  
  private
  
  def start_streaming_for_video(video)
    return if video.streaming_active
    
    # Create URL ingress for streaming
    ingress = LivekitService.create_ingress(
      name: "Stream: #{video.title}",
      room_name: video.room_name,
      participant_identity: "video-stream-#{video.video_id}",
      participant_name: "Video Stream",
      input_type: 'URL_INPUT',
      url: video.video_url,
      enable_transcoding: true,
      enabled: true,
      audio: {
        source: 'AUDIO_SOURCE_MICROPHONE',
        preset: 'AUDIO_PRESET_MUSIC_STEREO'
      },
      video: {
        source: 'VIDEO_SOURCE_SCREEN_SHARE',
        preset: 'H264_1080P_30FPS_3_LAYERS'
      }
    )
    
    # Update video record
    video.update!(
      ingress_id: ingress['ingressId'],
      ingress_url: ingress['url'],
      streaming_active: true,
      streaming_status: ingress['state'] ? ingress['state']['status'] : 'ENDPOINT_BUFFERING'
    )
  end
  
  def generate_viewer_token(video_id)
    video = Video.find_by!(video_id: video_id)
    LivekitService.create_access_token(
      room_name: video.room_name,
      identity: "viewer-#{SecureRandom.hex(4)}",
      name: "Viewer",
      metadata: { role: 'viewer', video_id: video_id }.to_json,
      can_publish: false,
      can_subscribe: true
    )
  end
  
  def generate_publisher_token(video_id)
    video = Video.find_by!(video_id: video_id)
    LivekitService.create_access_token(
      room_name: video.room_name,
      identity: "publisher-#{SecureRandom.hex(4)}",
      name: "Publisher",
      metadata: { role: 'publisher', video_id: video_id }.to_json,
      can_publish: true,
      can_subscribe: true
    )
  end
end
