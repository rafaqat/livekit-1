namespace :videos do
  desc "Migrate existing file-based videos to database"
  task migrate_to_db: :environment do
    puts "Starting video migration to database..."
    
    metadata_dir = Rails.root.join('storage', 'videos')
    
    if Dir.exist?(metadata_dir)
      json_files = Dir.glob(metadata_dir.join('*.json'))
      puts "Found #{json_files.length} video metadata files to migrate"
      
      json_files.each do |file|
        begin
          metadata = JSON.parse(File.read(file))
          video_id = metadata['video_id']
          
          # Check if already exists in database
          if Video.exists?(video_id: video_id)
            puts "  - Video #{video_id} already exists in database, skipping"
            next
          end
          
          # Create video record
          video = Video.create!(
            video_id: video_id,
            title: metadata['title'],
            description: metadata['description'],
            original_filename: metadata['original_filename'],
            file_size: metadata['file_size'],
            room_name: metadata['room_name'],
            ingress_id: metadata['ingress_id'],
            ingress_url: metadata['ingress_url'],
            stream_key: metadata['stream_key'],
            video_url: metadata['video_url'],
            streaming_active: metadata['streaming_active'] || false,
            streaming_status: metadata['streaming_status'] || 'NOT_STARTED',
            uploaded_at: metadata['uploaded_at'] || File.mtime(file)
          )
          
          puts "  ✓ Migrated video: #{video.title} (#{video_id})"
        rescue => e
          puts "  ✗ Failed to migrate #{file}: #{e.message}"
        end
      end
      
      puts "\nMigration complete!"
      puts "Total videos in database: #{Video.count}"
    else
      puts "No metadata directory found at #{metadata_dir}"
    end
  end
  
  desc "Clean up old JSON metadata files after migration"
  task cleanup_json: :environment do
    metadata_dir = Rails.root.join('storage', 'videos')
    
    if Dir.exist?(metadata_dir)
      json_files = Dir.glob(metadata_dir.join('*.json'))
      
      json_files.each do |file|
        metadata = JSON.parse(File.read(file))
        video_id = metadata['video_id']
        
        if Video.exists?(video_id: video_id)
          File.delete(file)
          puts "Deleted metadata file for #{video_id}"
        end
      end
      
      puts "Cleanup complete!"
    end
  end
end