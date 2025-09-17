namespace :video do
  desc "Create simple quality layers (separate MP4 files)"
  task :create_layers, [:video_id] => :environment do |t, args|
    video = Video.find_by(video_id: args[:video_id])
    raise "Video not found" unless video
    raise "Video file not found" unless video.file_exists?
    
    input_path = video.send(:file_path)
    
    # Create 3 quality versions as separate files
    qualities = [
      { suffix: '_360p', resolution: '640x360', bitrate: '600k' },
      { suffix: '_720p', resolution: '1280x720', bitrate: '1500k' },
      { suffix: '_1080p', resolution: '1920x1080', bitrate: '3000k' }
    ]
    
    qualities.each do |q|
      output_path = Rails.root.join('public', 'videos', "#{video.video_id}#{q[:suffix]}.mp4")
      
      cmd = %W[
        ffmpeg -i #{input_path}
        -c:v libx264 -preset fast -crf 22
        -c:a aac -b:a 128k
        -s #{q[:resolution]}
        -b:v #{q[:bitrate]}
        -movflags +faststart
        #{output_path}
      ].join(' ')
      
      puts "Creating #{q[:suffix]} version..."
      system(cmd)
    end
    
    puts "Created quality layers:"
    puts "  360p:  /videos/#{video.video_id}_360p.mp4"
    puts "  720p:  /videos/#{video.video_id}_720p.mp4"
    puts "  1080p: /videos/#{video.video_id}_1080p.mp4"
  end
end