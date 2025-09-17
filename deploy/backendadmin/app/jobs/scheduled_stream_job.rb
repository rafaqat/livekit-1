class ScheduledStreamJob < ApplicationJob
  queue_as :default

  PREWARM_LEAD_TIME = 5.minutes

  def perform
    Rails.logger.info "Running ScheduledStreamJob..."

    # Pre-warm ingress shortly before start time for scheduled broadcasts
    Video.streaming_mode_scheduled.find_each do |video|
      next unless video.scheduled_start_at.present?

      now = Time.current
      prewarm_window_start = video.scheduled_start_at - PREWARM_LEAD_TIME

      # Prewarm if in prewarm window and not already active
      if now >= prewarm_window_start && now < video.scheduled_start_at
        video.ensure_broadcast_ingress unless video.streaming_active && video.ingress_id.present?
      end

      # Start at or after scheduled time
      if now >= video.scheduled_start_at && (video.scheduled_end_at.nil? || now < video.scheduled_end_at)
        video.start_streaming! unless video.streaming_active
      end

      # Stop if past end time
      if video.scheduled_end_at.present? && now >= video.scheduled_end_at
        video.stop_streaming! if video.streaming_active
      end
    end

    Rails.logger.info "ScheduledStreamJob completed"
  end
end

