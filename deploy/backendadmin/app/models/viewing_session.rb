class ViewingSession < ApplicationRecord
  belongs_to :video, counter_cache: :total_views
  
  # Validations
  validates :viewer_identity, presence: true
  validates :started_at, presence: true
  
  # Scopes - wrapped to handle missing tables gracefully
  scope :active, -> { table_exists? ? where(ended_at: nil) : none }
  scope :completed, -> { table_exists? ? where.not(ended_at: nil) : none }
  scope :recent, -> { table_exists? ? order(started_at: :desc) : none }
  scope :today, -> { table_exists? ? where(started_at: Time.current.beginning_of_day..Time.current.end_of_day) : none }
  scope :this_week, -> { table_exists? ? where(started_at: Time.current.beginning_of_week..Time.current.end_of_week) : none }
  
  # Callbacks
  before_validation :set_started_at, on: :create
  after_update :update_video_analytics, if: :saved_change_to_ended_at?
  
  # Start a new viewing session
  def self.start_session(video, viewer_identity, viewer_ip, metadata = {})
    create!(
      video: video,
      viewer_identity: viewer_identity,
      viewer_ip: viewer_ip,
      room_name: video.room_name,
      started_at: Time.current,
      metadata: metadata
    )
  end
  
  # End the viewing session
  def end_session(quality_data = {})
    return if ended_at.present?

    with_lock do
      break if ended_at.present?
      self.ended_at = Time.current
      self.duration_seconds = (ended_at - started_at).to_i

      # Update quality metrics if provided
      if quality_data.present?
        self.quality_switches = quality_data[:switches] || self.quality_switches || 0
        self.average_quality = quality_data[:average_quality]
        self.average_bitrate = quality_data[:average_bitrate]
        self.buffering_events = quality_data[:buffering_events] || self.buffering_events || 0
        self.connection_drops = quality_data[:connection_drops] || self.connection_drops || 0
        self.quality_timeline = quality_data[:timeline] if quality_data[:timeline]
      end

      save!
    end
  end
  
  # Track quality change
  def track_quality_change(from_quality, to_quality, timestamp = Time.current)
    with_lock do
      self.quality_switches ||= 0
      self.quality_switches += 1

      timeline = quality_timeline || []
      timeline << {
        timestamp: timestamp,
        from: from_quality,
        to: to_quality
      }

      update!(
        quality_switches: quality_switches,
        quality_timeline: timeline
      )
    end
  end
  
  # Track buffering event
  def track_buffering(duration_ms = nil)
    with_lock do
      self.buffering_events ||= 0
      self.buffering_events += 1
      if metadata
        buffer_log = metadata['buffer_log'] || []
        buffer_log << {
          timestamp: Time.current,
          duration_ms: duration_ms
        }
        self.metadata = metadata.merge('buffer_log' => buffer_log)
      end
      save!
    end
  end
  
  # Track connection drop
  def track_connection_drop(reason = nil)
    with_lock do
      self.connection_drops ||= 0
      self.connection_drops += 1
      if metadata
        drop_log = metadata['drop_log'] || []
        drop_log << {
          timestamp: Time.current,
          reason: reason
        }
        self.metadata = metadata.merge('drop_log' => drop_log)
      end
      save!
    end
  end
  
  # Calculate watch percentage
  def watch_percentage
    return 0 unless video.duration_seconds && duration_seconds
    
    [(duration_seconds.to_f / video.duration_seconds * 100).round(2), 100.0].min
  end
  
  # Check if session completed most of the video
  def completed_viewing?
    watch_percentage >= 80
  end
  
  # Get session duration in human readable format
  def duration_human
    return 'In progress' unless ended_at
    
    seconds = duration_seconds || 0
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{seconds / 60}m #{seconds % 60}s"
    else
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      "#{hours}h #{minutes}m"
    end
  end
  
  private
  
  def set_started_at
    self.started_at ||= Time.current
  end
  
  def update_video_analytics
    video.update_analytics if video.present?
  end
end
