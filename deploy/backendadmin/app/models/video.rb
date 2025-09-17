class Video < ApplicationRecord
  # Associations
  has_many :viewing_sessions, dependent: :destroy
  
  # Validations
  validates :video_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :room_name, presence: true, uniqueness: true
  
  # Enums for state management
  enum :streaming_mode, {
    on_demand: 0,       # VOD - serve file directly, no ingress needed
    live_broadcast: 1,  # One ingress, many viewers (shared experience)
    scheduled: 2        # Will start at specific time
  }, prefix: true
  
  enum :ingress_state, {
    inactive: 0,
    initializing: 1,
    active: 2,
    ending: 3,
    completed: 4,
    error: 5
  }, prefix: true
  
  # Scopes - wrapped to handle missing tables gracefully
  scope :recent, -> { table_exists? ? order(uploaded_at: :desc) : none }
  scope :streaming, -> { table_exists? ? where(streaming_active: true) : none }
  scope :vod, -> { table_exists? ? where(streaming_mode: :on_demand) : none }
  scope :broadcast, -> { table_exists? ? where(streaming_mode: :live_broadcast) : none }
  
  # Callbacks
  before_create :set_uploaded_at
  before_create :set_default_mode
  after_save :extract_video_duration, if: :saved_change_to_video_id?
  
  # file_path defined at bottom to include extension
  
  def file_exists?
    File.exist?(file_path)
  end
  
  def file_size_mb
    (file_size / 1024.0 / 1024.0).round(2) if file_size
  end
  
  # VOD Methods
  def can_serve_directly?
    streaming_mode_on_demand? && file_exists?
  end
  
  # Generate access token based on mode
  def generate_viewing_token(viewer_identity, viewer_metadata = {}, session_id: nil)
    if streaming_mode_on_demand?
      # For VOD, generate a signed URL or simple token
      generate_vod_token(viewer_identity, viewer_metadata, session_id)
    else
      # For broadcast, use LiveKit room token
      LivekitService.create_access_token(
        room_name: room_name,
        identity: viewer_identity,
        name: viewer_metadata[:name] || viewer_identity,
        metadata: viewer_metadata.to_json,
        can_publish: false,
        can_subscribe: true
      )
    end
  end
  
  # Analytics Methods
  def increment_views!
    increment!(:total_views)
  end
  
  def update_analytics
    sessions = viewing_sessions.where('ended_at IS NOT NULL')
    
    update!(
      total_watch_seconds: sessions.sum(:duration_seconds),
      average_completion_rate: calculate_completion_rate
    )
  end
  
  def completion_rate
    return 0.0 if total_views == 0 || duration_seconds.nil?
    
    completed = viewing_sessions
      .where('duration_seconds > ?', duration_seconds * 0.8)
      .count
    
    (completed.to_f / total_views * 100).round(2)
  end
  
  # Ingress Management
  def ensure_broadcast_ingress
    return unless streaming_mode_live_broadcast?

    with_lock do
      if ingress_state_inactive? || ingress_state_completed? || ingress_state_error? || ingress_id.blank?
        create_broadcast_ingress
      else
        check_ingress_health
      end
    end
  end
  
  def create_broadcast_ingress
    return unless streaming_mode_live_broadcast?

    with_lock do
      # Delete old ingress if exists
      if ingress_id.present?
        LivekitService.delete_ingress(ingress_id) rescue nil
      end

      update!(ingress_state: :initializing)

      ingress = LivekitService.create_ingress(
        name: "Broadcast: #{title}",
        room_name: room_name,
        participant_identity: "video-stream-#{video_id}",
        participant_name: "Video Stream",
        input_type: 'URL_INPUT',
        url: video_url,
        enable_transcoding: true,
        enabled: true
      )

      state = ingress.dig('state', 'status')
      update!(
        ingress_id: ingress['ingressId'] || ingress['ingress_id'],
        ingress_url: ingress['url'],
        ingress_state: state == 'ENDPOINT_PUBLISHING' ? :active : :initializing,
        streaming_active: state == 'ENDPOINT_PUBLISHING',
        streaming_status: state || 'ENDPOINT_BUFFERING'
      )
    end
    
    Rails.logger.info "Created broadcast ingress #{ingress_id} for video #{video_id}"
  rescue => e
    Rails.logger.error "Failed to create ingress for video #{video_id}: #{e.message}"
    update!(ingress_state: :error, streaming_active: false)
    raise e
  end
  
  def check_ingress_health
    return unless ingress_id.present?
    
    ingress = LivekitService.list_ingress(ingress_id: ingress_id).first
    
    if ingress.nil?
      update!(ingress_state: :inactive, ingress_id: nil)
    elsif ingress['state']['status'] == 'ENDPOINT_COMPLETE'
      handle_ingress_completed
    elsif ingress['state']['status'] == 'ENDPOINT_ERROR'
      update!(ingress_state: :error)
    end
  rescue => e
    Rails.logger.error "Failed to check ingress health: #{e.message}"
  end
  
  def handle_ingress_completed
    update!(ingress_state: :completed, streaming_active: false)
    
    if auto_restart? || loop_video?
      Rails.logger.info "Auto-restarting ingress for video #{video_id}"
      create_broadcast_ingress
    end
  end
  
  def start_streaming!
    if streaming_mode_on_demand?
      update!(streaming_active: true, streaming_status: 'READY')
    else
      ensure_broadcast_ingress
    end
  end
  
  def stop_streaming!
    if ingress_id.present?
      LivekitService.delete_ingress(ingress_id) rescue nil
    end
    
    update!(
      streaming_active: false,
      streaming_status: 'STOPPED',
      ingress_state: :inactive,
      ingress_id: nil,
      ingress_url: nil
    )
  end

  def file_path
    ext = self[:file_extension].presence || 'mp4'
    Rails.root.join('public', 'videos', "#{video_id}.#{ext}")
  end
  
  private
  
  def set_uploaded_at
    self.uploaded_at ||= Time.current
  end
  
  def set_default_mode
    self.streaming_mode ||= :on_demand
  end
  
  def extract_video_duration
    return unless file_exists?
    seconds = ffprobe_duration || estimate_duration
    if seconds
      self.duration_seconds = seconds.to_i
      save
    end
  end
  
  def estimate_duration
    # Rough estimate: 1MB = ~8 seconds for average quality video
    return nil unless file_size
    (file_size / 1024.0 / 1024.0 * 8).round
  end
  
  def generate_vod_token(viewer_identity, metadata, session_id)
    # Simple token for VOD access
    # In production, use signed URLs or JWT tokens
    payload = {
      video_id: video_id,
      viewer: viewer_identity,
      session_id: session_id,
      exp: 1.hour.from_now.to_i,
      metadata: metadata
    }
    
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
  
  def calculate_completion_rate
    return 0.0 if viewing_sessions.count == 0 || duration_seconds.nil?
    
    completed = viewing_sessions
      .where('duration_seconds > ?', duration_seconds * 0.8)
      .count
    
    (completed.to_f / viewing_sessions.count * 100).round(2)
  end

  def ffprobe_duration
    return nil unless file_exists?
    path = file_path.to_s
    cmd = %(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{path}")
    out = `#{cmd}`.to_s.strip
    Float(out).round rescue nil
  end
end
