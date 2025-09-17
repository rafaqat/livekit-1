class IngressMonitorJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "Starting ingress monitoring check..."
    
    # Check all videos with active streaming
    Video.streaming.find_each do |video|
      check_video_ingress(video)
    end
    
    # Check broadcast mode videos that should have ingress
    Video.streaming_mode_live_broadcast.find_each do |video|
      ensure_broadcast_ready(video)
    end
    
    # Clean up stale viewing sessions
    cleanup_stale_sessions
    
    Rails.logger.info "Ingress monitoring check completed"
  end
  
  private
  
  def check_video_ingress(video)
    return unless video.ingress_id.present?
    
    ingress = LivekitService.list_ingress(ingress_id: video.ingress_id).first
    
    if ingress.nil?
      Rails.logger.warn "Ingress #{video.ingress_id} not found for video #{video.video_id}"
      video.with_lock do
        video.update!(
          ingress_state: :inactive,
          ingress_id: nil,
          streaming_active: false
        )
      end
      return
    end
    
    status = ingress['state']['status']
    
    case status
    when 'ENDPOINT_COMPLETE'
      handle_completed_ingress(video)
    when 'ENDPOINT_ERROR'
      handle_error_ingress(video)
    when 'ENDPOINT_BUFFERING'
      video.with_lock { video.update!(ingress_state: :initializing) } if video.ingress_state != 'initializing'
    when 'ENDPOINT_PUBLISHING'
      video.with_lock { video.update!(ingress_state: :active, streaming_active: true) } if video.ingress_state != 'active'
    when 'ENDPOINT_INACTIVE'
      video.with_lock { video.update!(ingress_state: :inactive, streaming_active: false) } if video.ingress_state != 'inactive'
    end
    
  rescue => e
    Rails.logger.error "Error checking ingress for video #{video.video_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
  
  def handle_completed_ingress(video)
    Rails.logger.info "Ingress completed for video #{video.video_id}"
    
    video.with_lock do
      video.update!(
        ingress_state: :completed,
        streaming_active: false
      )
    end
    
    # Auto-restart if configured
    if video.auto_restart? || video.loop_video?
      Rails.logger.info "Auto-restarting ingress for video #{video.video_id}"
      restart_ingress(video)
    else
      # Clean up completed ingress
      LivekitService.delete_ingress(video.ingress_id) rescue nil
      video.with_lock { video.update!(ingress_id: nil) }
    end
  end
  
  def handle_error_ingress(video)
    Rails.logger.error "Ingress error for video #{video.video_id}"
    
    video.with_lock do
      video.update!(
        ingress_state: :error,
        streaming_active: false
      )
    end
    
    # Retry if auto-restart is enabled
    if video.auto_restart?
      Rails.logger.info "Retrying ingress for video #{video.video_id} after error"
      sleep 5 # Wait before retry
      restart_ingress(video)
    end
  end
  
  def restart_ingress(video)
    # Delete old ingress
    if video.ingress_id.present?
      LivekitService.delete_ingress(video.ingress_id) rescue nil
      video.with_lock { video.update!(ingress_id: nil) }
    end
    
    # Create new ingress
    video.create_broadcast_ingress
  rescue => e
    Rails.logger.error "Failed to restart ingress for video #{video.video_id}: #{e.message}"
    video.update!(ingress_state: :error, streaming_active: false)
  end
  
  def ensure_broadcast_ready(video)
    # Skip if VOD mode
    return if video.streaming_mode_on_demand?
    
    # Check if ingress needs to be created or restarted
    if video.streaming_active && !video.ingress_id.present?
      Rails.logger.info "Creating missing ingress for broadcast video #{video.video_id}"
      video.create_broadcast_ingress
    elsif video.ingress_state_error? || video.ingress_state_completed?
      if video.auto_restart? || video.loop_video?
        Rails.logger.info "Restarting ingress for broadcast video #{video.video_id}"
        restart_ingress(video)
      end
    end
  end
  
  def cleanup_stale_sessions
    # End sessions that have been inactive for more than 30 minutes
    stale_time = 30.minutes.ago
    
    ViewingSession.active
      .where('updated_at < ?', stale_time)
      .find_each do |session|
        Rails.logger.info "Ending stale viewing session #{session.id}"
        session.end_session
      end
  end
end
