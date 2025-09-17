namespace :video do
  desc "Clean all video data from database and file system"
  task cleanup: :environment do
    puts "Starting video cleanup..."
    
    # Clean database
    viewing_sessions_count = ViewingSession.count
    videos_count = Video.count
    
    ViewingSession.destroy_all
    Video.destroy_all
    
    puts "✓ Cleaned database:"
    puts "  - Removed #{videos_count} videos"
    puts "  - Removed #{viewing_sessions_count} viewing sessions"
    
    # Clean file system
    video_dir = Rails.root.join('public', 'videos')
    
    if Dir.exist?(video_dir)
      # Count files before deletion
      files = Dir.glob(File.join(video_dir, '*'))
      file_count = files.count
      
      # Remove all files but keep the directory
      files.each do |file|
        File.delete(file) if File.file?(file)
        FileUtils.rm_rf(file) if File.directory?(file) && !file.end_with?('videos')
      end
      
      puts "✓ Cleaned file system:"
      puts "  - Removed #{file_count} files/folders from #{video_dir}"
    else
      # Create the directory if it doesn't exist
      FileUtils.mkdir_p(video_dir)
      puts "✓ Created video directory: #{video_dir}"
    end
    
    puts "\n✅ Video cleanup complete!"
    puts "Database and file system are now clean."
  end
  
  desc "Show video statistics"
  task stats: :environment do
    puts "\n📊 Video Statistics:"
    puts "=" * 40
    
    # Database stats
    puts "\nDatabase:"
    puts "  - Videos: #{Video.count}"
    puts "  - Viewing Sessions: #{ViewingSession.count}"
    
    # File system stats
    video_dir = Rails.root.join('public', 'videos')
    if Dir.exist?(video_dir)
      files = Dir.glob(File.join(video_dir, '**/*'))
      video_files = files.select { |f| f.match?(/\.(mp4|m3u8|ts)$/i) }
      total_size = files.select { |f| File.file?(f) }.sum { |f| File.size(f) }
      
      puts "\nFile System (#{video_dir}):"
      puts "  - Total files: #{files.count}"
      puts "  - Video files: #{video_files.count}"
      puts "  - Total size: #{(total_size / 1024.0 / 1024.0).round(2)} MB"
      
      # List video files
      if video_files.any?
        puts "\n  Video files:"
        video_files.each do |file|
          size_mb = (File.size(file) / 1024.0 / 1024.0).round(2)
          puts "    - #{File.basename(file)} (#{size_mb} MB)"
        end
      end
    else
      puts "\nFile System: Video directory does not exist"
    end
    
    puts "=" * 40
  end
end