class StreamsController < ApplicationController
  def index
    @streams = Dir.glob(Rails.root.join('storage', 'streams', '*.mp4')).map do |file|
      json_file = file.sub('.mp4', '.json')
      metadata = File.exist?(json_file) ? JSON.parse(File.read(json_file)) : {}
      
      {
        filename: File.basename(file),
        path: file,
        size: (File.size(file) / 1024.0 / 1024.0).round(2), # MB
        created_at: File.ctime(file),
        video_id: metadata['video_id'] || File.basename(file, '.mp4'),
        streaming_active: metadata['streaming_active'] || false,
        room_name: metadata['room_name']
      }
    end
    @rooms = LivekitService.list_rooms
    @ingresses = LivekitService.list_ingress
  rescue => e
    @error = e.message
    @streams = []
    @rooms = []
    @ingresses = []
  end
  
  def new
    @rooms = LivekitService.list_rooms
  end
  
  def create
    if params[:file].present?
      # Ensure streams directory exists
      streams_dir = Rails.root.join('storage', 'streams')
      FileUtils.mkdir_p(streams_dir)
      
      # Save uploaded file
      uploaded_file = params[:file]
      filename = "#{Time.now.to_i}_#{uploaded_file.original_filename}"
      filepath = streams_dir.join(filename)
      
      File.open(filepath, 'wb') do |file|
        file.write(uploaded_file.read)
      end
      
      # Create ingress for streaming
      if params[:create_ingress] == 'true'
        room_name = params[:room_name] || "stream-#{Time.now.to_i}"
        
        # Create room if it doesn't exist
        begin
          LivekitService.get_room(room_name)
        rescue
          LivekitService.create_room(room_name, max_participants: 100)
        end
        
        # Create RTMP ingress
        @ingress = LivekitService.create_ingress(
          name: "Stream: #{filename}",
          room_name: room_name,
          participant_identity: "streamer-#{Time.now.to_i}",
          participant_name: "Media Streamer",
          input_type: 'RTMP_INPUT'
        )
        
        # Store streaming info
        streaming_info = {
          file: filepath.to_s,
          room_name: room_name,
          ingress_id: @ingress['ingressId'],
          rtmp_url: @ingress['url'],
          stream_key: @ingress['streamKey'],
          created_at: Time.now
        }
        
        File.write(filepath.sub('.mp4', '.json'), streaming_info.to_json)
        
        redirect_to streams_path, notice: "File uploaded and ingress created. RTMP URL: #{@ingress['url']}, Stream Key: #{@ingress['streamKey']}"
      else
        redirect_to streams_path, notice: "File uploaded successfully"
      end
    else
      redirect_to new_stream_path, alert: "Please select a file to upload"
    end
  rescue => e
    redirect_to streams_path, alert: "Upload failed: #{e.message}"
  end
  
  def destroy
    filename = params[:id]
    filepath = Rails.root.join('storage', 'streams', filename)
    
    # Delete associated files
    File.delete(filepath) if File.exist?(filepath)
    json_file = filepath.sub('.mp4', '.json')
    
    if File.exist?(json_file)
      streaming_info = JSON.parse(File.read(json_file))
      # Delete ingress if exists
      if streaming_info['ingress_id']
        LivekitService.delete_ingress(streaming_info['ingress_id']) rescue nil
      end
      File.delete(json_file)
    end
    
    redirect_to streams_path, notice: "Stream deleted successfully"
  rescue => e
    redirect_to streams_path, alert: "Failed to delete stream: #{e.message}"
  end
  
  def start_stream
    filename = params[:id]
    filepath = Rails.root.join('storage', 'streams', filename)
    json_file = filepath.sub('.mp4', '.json')
    
    if File.exist?(json_file)
      @streaming_info = JSON.parse(File.read(json_file))
      
      # Generate FFmpeg command for streaming
      @ffmpeg_command = generate_ffmpeg_command(filepath, @streaming_info['rtmp_url'], @streaming_info['stream_key'])
      
      # Start streaming in background (you would run this on the server)
      # For now, we'll just show the command
      render json: {
        status: 'ready',
        rtmp_url: @streaming_info['rtmp_url'],
        stream_key: @streaming_info['stream_key'],
        room_name: @streaming_info['room_name'],
        playback_url: generate_playback_url(@streaming_info['room_name']),
        ffmpeg_command: @ffmpeg_command,
        message: "Run this FFmpeg command on your server to start streaming"
      }
    else
      render json: { error: "No streaming configuration found for this file" }, status: 404
    end
  end
  
  def generate_token
    room_name = params[:room_name]
    identity = params[:identity] || "viewer-#{Time.now.to_i}"
    
    token = LivekitService.create_token(
      room_name: room_name,
      identity: identity,
      name: params[:name] || identity,
      can_publish: false,
      can_subscribe: true
    )
    
    render json: {
      token: token,
      url: "wss://livekit.lovedrop.live",
      room_name: room_name
    }
  end
  
  private
  
  def generate_ffmpeg_command(filepath, rtmp_url, stream_key)
    # FFmpeg command to stream MP4 to RTMP
    "ffmpeg -re -i #{filepath} -c:v libx264 -preset veryfast -maxrate 3000k -bufsize 6000k " \
    "-pix_fmt yuv420p -g 50 -c:a aac -b:a 160k -ac 2 -ar 44100 " \
    "-f flv #{rtmp_url}/#{stream_key}"
  end
  
  def generate_playback_url(room_name)
    # Generate a URL that iOS app can use to connect
    token = LivekitService.create_token(
      room_name: room_name,
      identity: "ios-viewer-#{Time.now.to_i}",
      name: "iOS Viewer",
      can_publish: false,
      can_subscribe: true
    )
    
    {
      websocket_url: "wss://livekit.lovedrop.live",
      token: token,
      room_name: room_name
    }
  end
end