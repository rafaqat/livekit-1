class VideoTranscodeJob < ApplicationJob
  queue_as :default
  
  def perform(video_id)
    video = Video.find_by(video_id: video_id)
    return unless video && video.file_exists?
    
    Rails.logger.info "Starting transcode for video #{video_id}"
    
    # Run the rake task
    system("bin/rails video:transcode[#{video_id}]")
    
    # Optionally create DASH as well
    # system("bin/rails video:dash[#{video_id}]")
    
    Rails.logger.info "Transcode complete for video #{video_id}"
  end
end