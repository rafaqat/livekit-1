namespace :videos do
  desc "Import existing JSON metadata to database"
  task import_to_db: :environment do
    puts "Importing videos to database..."
    
    metadata_dir = Rails.root.join('storage', 'videos')
    imported = 0
    skipped = 0
    
    if Dir.exist?(metadata_dir)
      Dir.glob(metadata_dir.join('*.json')).each do |file|
        begin
          metadata = JSON.parse(File.read(file))
          video_id = metadata['video_id']
          
          # Check if already exists
          if Video.exists?(video_id: video_id)
            puts "  - Video #{video_id} already in database, skipping"
            skipped += 1
            next
          end
          
          # Create video record
          Video.create!(
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
          
          puts "  ✓ Imported: #{metadata['title']} (#{video_id})"
          imported += 1
        rescue => e
          puts "  ✗ Failed to import #{file}: #{e.message}"
        end
      end
    end
    
    puts "\nImport complete!"
    puts "  Imported: #{imported}"
    puts "  Skipped: #{skipped}"
    puts "  Total in database: #{Video.count}"
  end
end