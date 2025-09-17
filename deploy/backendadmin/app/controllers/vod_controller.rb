class VodController < ApplicationController
  before_action :set_video
  before_action :validate_token, only: [:stream]
  
  def watch
    # VOD viewing page
    # Start viewing session for analytics first (ensures counter_cache and token correlation)
    @session = ViewingSession.start_session(
      @video,
      viewer_identity,
      request.remote_ip,
      viewer_metadata
    )
    
    # Generate token after session is created so we can embed session_id
    @viewing_token = @video.generate_viewing_token(
      viewer_identity,
      viewer_metadata,
      session_id: @session.id
    )
  end
  
  def stream
    # Direct video streaming for VOD
    unless @video.can_serve_directly?
      render json: { error: 'Video not available for streaming' }, status: 404
      return
    end
    
    # Stream the video file
    send_file @video.file_path,
      type: 'video/mp4',
      disposition: 'inline',
      range: true
  end
  
  def get_token
    # Generate token for VOD access
    # Create or get viewing session first
    session = ViewingSession.find_or_create_by(
      video: @video,
      viewer_identity: viewer_identity,
      ended_at: nil
    ) do |s|
      s.viewer_ip = request.remote_ip
      s.room_name = @video.room_name
      s.metadata = viewer_metadata
    end
    
    token = @video.generate_viewing_token(
      viewer_identity,
      viewer_metadata,
      session_id: session.id
    )
    
    render json: {
      success: true,
      video: {
        id: @video.video_id,
        title: @video.title,
        duration: @video.duration_seconds,
        mode: @video.streaming_mode
      },
      access: {
        token: token,
        url: @video.streaming_mode_on_demand? ? video_stream_url(@video.video_id) : nil,
        websocket_url: @video.streaming_mode_live_broadcast? ? ENV['LIVEKIT_WS_URL'] : nil,
        room_name: @video.streaming_mode_live_broadcast? ? @video.room_name : nil
      },
      session: {
        id: session.id,
        started_at: session.started_at
      }
    }
  end
  
  def update_session
    # Update viewing session with quality metrics
    session = ViewingSession.find(params[:session_id])
    # Authenticate using VOD token to prevent spoofing
    token = params[:token] || request.headers['Authorization']&.split(' ')&.last
    unless token
      render json: { error: 'Token required' }, status: 401 and return
    end
    begin
      payload = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256', verify_expiration: true, leeway: 30 }).first
      if payload['video_id'] != @video.video_id || payload['session_id'].to_s != session.id.to_s
        render json: { error: 'Unauthorized session update' }, status: 403 and return
      end
    rescue JWT::DecodeError
      render json: { error: 'Invalid token' }, status: 401 and return
    end
    
    if params[:event] == 'quality_change'
      session.track_quality_change(
        params[:from_quality],
        params[:to_quality]
      )
    elsif params[:event] == 'buffering'
      session.track_buffering(params[:duration_ms])
    elsif params[:event] == 'connection_drop'
      session.track_connection_drop(params[:reason])
    elsif params[:event] == 'end'
      session.end_session(
        switches: params[:quality_switches],
        average_quality: params[:average_quality],
        average_bitrate: params[:average_bitrate],
        buffering_events: params[:buffering_events],
        connection_drops: params[:connection_drops],
        timeline: params[:quality_timeline]
      )
    end
    
    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Session not found' }, status: 404
  end
  
  def analytics
    # Get video analytics
    sessions = @video.viewing_sessions.includes(:video)
    
    stats = {
      video_id: @video.video_id,
      title: @video.title,
      total_views: @video.total_views,
      unique_viewers: sessions.distinct.count(:viewer_identity),
      total_watch_time: @video.total_watch_seconds,
      average_watch_duration: sessions.completed.average(:duration_seconds)&.round || 0,
      completion_rate: @video.completion_rate,
      
      quality_stats: {
        average_switches: sessions.completed.average(:quality_switches)&.round(2) || 0,
        average_buffering: sessions.completed.average(:buffering_events)&.round(2) || 0,
        average_drops: sessions.completed.average(:connection_drops)&.round(2) || 0
      },
      
      recent_sessions: sessions.recent.limit(10).map { |s|
        {
          viewer: s.viewer_identity,
          started_at: s.started_at,
          duration: s.duration_human,
          watch_percentage: s.watch_percentage,
          quality_switches: s.quality_switches,
          buffering_events: s.buffering_events
        }
      },
      
      hourly_views: sessions.today.group_by_hour(:started_at).count,
      daily_views: sessions.this_week.group_by_day(:started_at).count
    }
    
    render json: stats
  end
  
  private
  
  def set_video
    @video = Video.find_by!(video_id: params[:video_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Video not found' }, status: 404
  end
  
  def validate_token
    return true unless @video.streaming_mode_on_demand?
    
    token = params[:token] || request.headers['Authorization']&.split(' ')&.last
    
    unless token
      render json: { error: 'Token required' }, status: 401
      return false
    end
    
    begin
      payload = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256', verify_expiration: true, leeway: 30 }).first
      
      if payload['video_id'] != @video.video_id
        render json: { error: 'Invalid token for this video' }, status: 403
        return false
      end
      
      @viewer_identity = payload['viewer']
      @viewer_metadata = payload['metadata'] || {}
      true
    rescue JWT::DecodeError => e
      render json: { error: 'Invalid token' }, status: 401
      false
    end
  end
  
  def viewer_identity
    @viewer_identity ||= "viewer-#{SecureRandom.hex(8)}"
  end
  
  def viewer_metadata
    @viewer_metadata ||= {
      user_agent: request.user_agent,
      ip: request.remote_ip,
      timestamp: Time.current
    }
  end
end
