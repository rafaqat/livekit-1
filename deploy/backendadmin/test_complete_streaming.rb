#!/usr/bin/env ruby
require_relative 'config/environment'
require 'net/http'
require 'json'
require 'jwt'
require 'fileutils'

puts "=== Complete URL_INPUT Video Streaming Test ==="
puts

# Step 1: Ensure videos directory exists
video_dir = Rails.root.join('public', 'videos')
FileUtils.mkdir_p(video_dir)
puts "✅ Videos directory ready: #{video_dir}"

# Step 2: Create test video file (using a sample URL)
video_id = "demo_#{Time.now.to_i}"
video_filename = "#{video_id}.mp4"
video_path = video_dir.join(video_filename)

# Download sample video
sample_url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
puts "\n Downloading sample video..."
system("curl -L -o #{video_path} '#{sample_url}' --max-time 30 --progress-bar")

if File.exist?(video_path)
  file_size = File.size(video_path)
  puts "✅ Video downloaded: #{(file_size / 1024.0 / 1024.0).round(2)} MB"
else
  puts "❌ Failed to download video"
  exit 1
end

# Step 3: Create database record
room_name = "room_#{video_id}"
video = Video.create!(
  video_id: video_id,
  title: "Big Buck Bunny Demo",
  description: "Test video for URL_INPUT streaming",
  room_name: room_name,
  file_size: file_size,
  uploaded_at: Time.current
)

puts "\n✅ Video record created:"
puts "  - Video ID: #{video.video_id}"
puts "  - Room: #{video.room_name}"
puts "  - File: /videos/#{video_filename}"

# Step 4: Start Rails server in background to serve the video file
video_url = "https://admin.livekit.lovedrop.live/videos/#{video_filename}"
puts "\n Video will be accessible at: #{video_url}"

# Step 5: Create URL_INPUT ingress
api_key = 'd2493690c7c87be587586ebf10cfeaeb'
api_secret = 'PXRsXXfyXZjl1SsfUbN3Z+gsWhNxCG/6N49F6pNVknY='

payload = {
  iss: api_key,
  exp: Time.now.to_i + 3600,
  video: {
    ingressAdmin: true
  }
}

token = JWT.encode(payload, api_secret, 'HS256')

uri = URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/CreateIngress')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'

request_body = {
  input_type: "URL_INPUT",  # String format works!
  name: "Stream: #{video.title}",
  room_name: video.room_name,
  url: video_url,
  participant_identity: "video_streamer_#{video.video_id}",
  participant_name: "Video Player",
  bypass_transcoding: false,
  enable_transcoding: true,
  video: {
    source: "VIDEO_SOURCE_SCREEN_SHARE",
    preset: "H264_1080P_30FPS_3_LAYERS"  # Simulcast with 3 quality layers
  },
  audio: {
    source: "AUDIO_SOURCE_MICROPHONE",
    preset: "OPUS_STEREO_96KBPS"
  }
}

puts "\n Creating URL_INPUT ingress..."
request.body = request_body.to_json

response = http.request(request)

if response.code == '200'
  data = JSON.parse(response.body)
  ingress_id = data['ingress_id'] || data['ingressId']
  
  puts "\n✅ URL_INPUT Ingress Created Successfully!"
  puts "="*50
  puts JSON.pretty_generate(data)
  puts "="*50
  
  # Update video record
  video.update!(
    ingress_id: ingress_id,
    ingress_url: video_url,
    streaming_active: true,
    streaming_status: data['state'] ? data['state']['status'] : 'STARTING'
  )
  
  puts "\n Ingress Configuration:"
  puts "  - Ingress ID: #{ingress_id}"
  puts "  - Video URL: #{video_url}"
  puts "  - Room Name: #{video.room_name}"
  puts "  - Status: #{video.streaming_status}"
  
  # Step 6: Monitor ingress status
  puts "\n Monitoring ingress status..."
  
  5.times do |i|
    sleep(2)
    
    list_request = Net::HTTP::Post.new(URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/ListIngress'))
    list_request['Authorization'] = "Bearer #{token}"
    list_request['Content-Type'] = 'application/json'
    list_request.body = { ingress_id: ingress_id }.to_json
    
    list_response = http.request(list_request)
    if list_response.code == '200'
      list_data = JSON.parse(list_response.body)
      if list_data['items'] && list_data['items'].any?
        ingress = list_data['items'].first
        status = ingress['state']['status']
        
        print "\r  [#{i+1}/5] Status: #{status}"
        
        if status == 'ENDPOINT_ACTIVE'
          puts "\n\n🎉 SUCCESS! Video is now streaming!"
          puts "\n Connection Info for iOS App:"
          puts "  - WebSocket URL: wss://livekit.lovedrop.live"
          puts "  - Room Name: #{video.room_name}"
          puts "  - Viewer Token: (generate with /videos/#{video.video_id}/play endpoint)"
          break
        elsif status == 'ENDPOINT_ERROR'
          puts "\n\n❌ Streaming error: #{ingress['state']['error']}"
          break
        end
      end
    end
  end
  
  puts "\n\n Test Complete!"
  puts "  - Video is stored at: public/videos/#{video_filename}"
  puts "  - Database record: Video ID #{video.video_id}"
  puts "  - Ingress ID: #{ingress_id}"
  puts "\n To stop streaming, run:"
  puts "  rails runner \"LivekitService.delete_ingress('#{ingress_id}')\""
  
else
  puts "\n❌ Failed to create ingress"
  error = JSON.parse(response.body) rescue {}
  puts "Error: #{error['msg'] || response.body}"
end