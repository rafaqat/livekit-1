namespace :video do
  desc "Pre-transcode video into multiple quality layers"
  task :transcode, [:video_id] => :environment do |t, args|
    video = Video.find_by(video_id: args[:video_id])
    raise "Video not found" unless video
    raise "Video file not found" unless video.file_exists?
    
    input_path = video.send(:file_path)
    output_dir = Rails.root.join('public', 'videos', 'hls', video.video_id)
    FileUtils.mkdir_p(output_dir)
    
    # Create multiple quality versions
    qualities = [
      { name: 'low', resolution: '640x360', bitrate: '600k', audio: '96k' },
      { name: 'medium', resolution: '1280x720', bitrate: '1500k', audio: '128k' },
      { name: 'high', resolution: '1920x1080', bitrate: '3000k', audio: '192k' }
    ]
    
    # Generate HLS segments for each quality
    qualities.each do |q|
      output_path = output_dir.join("#{q[:name]}.m3u8")
      
      cmd = %W[
        ffmpeg -i #{input_path}
        -c:v libx264 -c:a aac
        -s #{q[:resolution]}
        -b:v #{q[:bitrate]} -b:a #{q[:audio]}
        -g 48 -keyint_min 48 -sc_threshold 0
        -hls_time 6 -hls_playlist_type vod
        -hls_segment_filename #{output_dir}/#{q[:name]}_%03d.ts
        #{output_path}
      ].join(' ')
      
      puts "Creating #{q[:name]} quality layer..."
      system(cmd)
    end
    
    # Create master playlist
    master_playlist = output_dir.join('master.m3u8')
    File.open(master_playlist, 'w') do |f|
      f.puts "#EXTM3U"
      f.puts "#EXT-X-VERSION:3"
      
      qualities.each do |q|
        bandwidth = q[:bitrate].to_i * 1000
        f.puts "#EXT-X-STREAM-INF:BANDWIDTH=#{bandwidth},RESOLUTION=#{q[:resolution]}"
        f.puts "#{q[:name]}.m3u8"
      end
    end
    
    puts "Transcoding complete! HLS files at: #{output_dir}"
    puts "Master playlist: /videos/hls/#{video.video_id}/master.m3u8"
    
    # Update video record
    video.update!(
      hls_ready: true,
      hls_path: "/videos/hls/#{video.video_id}/master.m3u8"
    )
  end
  
  desc "Create DASH manifest for adaptive streaming"
  task :dash, [:video_id] => :environment do |t, args|
    video = Video.find_by(video_id: args[:video_id])
    raise "Video not found" unless video
    
    input_path = video.send(:file_path)
    output_dir = Rails.root.join('public', 'videos', 'dash', video.video_id)
    FileUtils.mkdir_p(output_dir)
    
    # Create DASH segments with multiple bitrates
    cmd = %W[
      ffmpeg -i #{input_path}
      -map 0:v -map 0:v -map 0:v -map 0:a
      -c:v libx264 -c:a aac
      -b:v:0 600k -s:v:0 640x360
      -b:v:1 1500k -s:v:1 1280x720  
      -b:v:2 3000k -s:v:2 1920x1080
      -b:a 128k
      -use_timeline 1 -use_template 1
      -init_seg_name init-$RepresentationID$.mp4
      -media_seg_name chunk-$RepresentationID$-$Number$.m4s
      -f dash #{output_dir}/manifest.mpd
    ].join(' ')
    
    puts "Creating DASH manifest..."
    system(cmd)
    
    video.update!(
      dash_ready: true,
      dash_path: "/videos/dash/#{video.video_id}/manifest.mpd"
    )
  end
end