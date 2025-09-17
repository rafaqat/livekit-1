class StreamingTestController < ApplicationController
  def index
    @videos = Video.recent.select { |v| v.file_exists? }
    @test_configs = generate_test_configs
  end
  
  def test_stream
    video_id = params[:video_id]
    test_config = params[:test_config]
    
    video = Video.find_by!(video_id: video_id)
    unless video.file_exists?
      render json: { error: "Video file not found" }, status: 404
      return
    end
    
    # Create viewing session for analytics
    viewer_identity = "test-#{test_config[:client_type]}-#{SecureRandom.hex(4)}"
    session = ViewingSession.start_session(
      video,
      viewer_identity,
      request.remote_ip,
      { test_mode: true, config: test_config }
    )
    
    # Handle based on streaming mode
    if video.streaming_mode_on_demand?
      # VOD mode - no ingress needed
      test_token = video.generate_viewing_token(viewer_identity, test_config)
      
      render json: {
        success: true,
        mode: 'vod',
        video: {
          id: video.video_id,
          title: video.title,
          file_size_mb: video.file_size_mb,
          duration: video.duration_seconds,
          streaming_mode: video.streaming_mode
        },
        connection: {
          video_url: video_stream_url(video.video_id, token: test_token),
          token: test_token
        },
        session: {
          id: session.id,
          started_at: session.started_at
        },
        test_config: test_config,
        test_scenarios: get_test_scenarios
      }
    else
      # Broadcast mode - needs ingress
      unless video.streaming_active && video.ingress_id.present?
        video.ensure_broadcast_ingress
        video.reload # Reload to get updated info
      end
      
      # Generate test token with specific configurations
      test_token = generate_test_token(video, test_config)
      
      # Get room stats if available
      room_stats = get_room_stats(video.room_name) rescue nil
      
      render json: {
        success: true,
        mode: 'broadcast',
        video: {
          id: video.video_id,
          title: video.title,
          room_name: video.room_name,
          file_size_mb: video.file_size_mb,
          duration: video.duration_seconds,
          streaming_active: video.streaming_active,
          ingress_id: video.ingress_id,
          ingress_state: video.ingress_state,
          streaming_mode: video.streaming_mode
        },
        connection: {
          websocket_url: ENV['LIVEKIT_WS_URL'] || 'wss://livekit.lovedrop.live',
          token: test_token,
          room_name: video.room_name
        },
        session: {
          id: session.id,
          started_at: session.started_at
        },
        test_config: test_config,
        room_stats: room_stats,
        simulcast_layers: get_simulcast_info(test_config),
        test_scenarios: get_test_scenarios
      }
    end
  rescue => e
    render json: { error: e.message }, status: 500
  end
  
  def stop_test
    video_id = params[:video_id]
    video = Video.find_by(video_id: video_id)
    
    if video && video.ingress_id
      LivekitService.delete_ingress(video.ingress_id) rescue nil
      video.stop_streaming!
      
      render json: { success: true, message: "Streaming stopped" }
    else
      render json: { success: false, message: "No active stream" }
    end
  rescue => e
    render json: { error: e.message }, status: 500
  end
  
  def room_stats
    room_name = params[:room_name]
    
    stats = {
      room_name: room_name,
      participants: LivekitService.list_participants(room_name),
      room_info: LivekitService.get_room(room_name),
      timestamp: Time.now
    }
    
    render json: stats
  rescue => e
    render json: { error: e.message, room_name: room_name }, status: 500
  end
  
  private
  
  def generate_test_configs
    {
      quality_presets: [
        { id: 'auto', name: 'Auto (Adaptive)', description: 'Automatically adapt to network conditions' },
        { id: 'high', name: 'High (1080p)', description: 'Force highest quality layer' },
        { id: 'medium', name: 'Medium (720p)', description: 'Force medium quality layer' },
        { id: 'low', name: 'Low (360p)', description: 'Force lowest quality layer' }
      ],
      network_conditions: [
        { id: 'excellent', name: 'Excellent (>10 Mbps)', bandwidth: 10000, latency: 20, packet_loss: 0 },
        { id: 'good', name: 'Good (5-10 Mbps)', bandwidth: 5000, latency: 50, packet_loss: 0.1 },
        { id: 'fair', name: 'Fair (2-5 Mbps)', bandwidth: 2000, latency: 100, packet_loss: 0.5 },
        { id: 'poor', name: 'Poor (1-2 Mbps)', bandwidth: 1000, latency: 200, packet_loss: 1 },
        { id: 'terrible', name: 'Terrible (<1 Mbps)', bandwidth: 500, latency: 500, packet_loss: 3 }
      ],
      video_codecs: [
        { id: 'h264', name: 'H.264', description: 'Most compatible codec' },
        { id: 'vp8', name: 'VP8', description: 'WebRTC standard codec' },
        { id: 'vp9', name: 'VP9', description: 'Better compression than VP8' }
      ],
      test_durations: [
        { id: '30s', name: '30 seconds', duration: 30 },
        { id: '1m', name: '1 minute', duration: 60 },
        { id: '5m', name: '5 minutes', duration: 300 },
        { id: 'unlimited', name: 'Unlimited', duration: nil }
      ],
      client_types: [
        { id: 'ios', name: 'iOS App', user_agent: 'LiveKit-iOS/1.0' },
        { id: 'android', name: 'Android App', user_agent: 'LiveKit-Android/1.0' },
        { id: 'web', name: 'Web Browser', user_agent: 'LiveKit-Web/1.0' },
        { id: 'desktop', name: 'Desktop App', user_agent: 'LiveKit-Desktop/1.0' }
      ]
    }
  end
  
  def generate_test_token(video, config)
    room_name = video.room_name
    identity = "test-#{config[:client_type]}-#{SecureRandom.hex(4)}"
    
    metadata = {
      test_mode: true,
      quality_preset: config[:quality],
      network_condition: config[:network],
      codec: config[:codec],
      client_type: config[:client_type],
      test_started: Time.now
    }.to_json
    
    LivekitService.create_access_token(
      room_name: room_name,
      identity: identity,
      name: "Test Client (#{config[:client_type]})",
      metadata: metadata,
      can_publish: false,
      can_subscribe: true
    )
  end
  
  def start_streaming_for_video(video)
    # Delegate to model to ensure unified lifecycle and locking
    video.ensure_broadcast_ingress
  end
  
  def get_room_stats(room_name)
    participants = LivekitService.list_participants(room_name)
    
    {
      participant_count: participants.length,
      participants: participants.map { |p|
        {
          identity: p['identity'],
          name: p['name'],
          state: p['state'],
          tracks: p['tracks']&.map { |t|
            {
              sid: t['sid'],
              type: t['type'],
              source: t['source'],
              muted: t['muted'],
              simulcast: t['simulcast']
            }
          }
        }
      }
    }
  rescue => e
    Rails.logger.error "Failed to get room stats: #{e.message}"
    nil
  end
  
  def get_simulcast_info(config)
    quality = config[:quality] || 'auto'
    
    case quality
    when 'high'
      { active_layer: 2, resolution: '1920x1080', bitrate: '3000kbps', fps: 30 }
    when 'medium'
      { active_layer: 1, resolution: '1280x720', bitrate: '1500kbps', fps: 30 }
    when 'low'
      { active_layer: 0, resolution: '640x360', bitrate: '600kbps', fps: 30 }
    else
      { active_layer: 'auto', resolution: 'adaptive', bitrate: 'adaptive', fps: 30 }
    end
  end
  
  def get_test_scenarios
    [
      {
        name: 'Network Degradation Test',
        description: 'Gradually degrade network to test adaptive bitrate',
        steps: ['Start with excellent', 'Degrade to good after 30s', 'Degrade to poor after 60s']
      },
      {
        name: 'Quality Switch Test',
        description: 'Force quality changes to test layer switching',
        steps: ['Start with high quality', 'Switch to low after 20s', 'Switch to medium after 40s']
      },
      {
        name: 'Connection Stability Test',
        description: 'Test reconnection and recovery',
        steps: ['Connect normally', 'Simulate disconnect', 'Test auto-reconnect']
      },
      {
        name: 'Multi-Client Test',
        description: 'Test with multiple simultaneous viewers',
        steps: ['Connect first client', 'Add 5 more clients', 'Monitor quality adaptation']
      }
    ]
  end
  
  def get_video_duration(file_path)
    # Placeholder - would need FFmpeg to get actual duration
    # For now, return a default or estimate based on file size
    file_size_mb = File.size(file_path) / 1024.0 / 1024.0
    (file_size_mb * 8).round # Rough estimate: 8 seconds per MB
  rescue
    nil
  end
end
