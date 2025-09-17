#!/usr/bin/env ruby
require_relative 'config/environment'
require 'net/http'
require 'json'
require 'jwt'

# Use the existing video that's already on the server
video = Video.find_by(video_id: "demo_1757772661")

if !video
  puts "Creating database record for existing video..."
  video = Video.create!(
    video_id: "demo_1757772661",
    title: "Big Buck Bunny Demo",
    room_name: "room_demo_1757772661",
    file_size: 157953475,
    uploaded_at: Time.current
  )
end

puts "=== Testing URL_INPUT Streaming with Deployed Video ==="
puts
puts "Video: #{video.title}"
puts "Video ID: #{video.video_id}"
puts "Room: #{video.room_name}"

video_url = "https://admin.livekit.lovedrop.live/videos/demo_1757772661.mp4"
puts "Video URL: #{video_url}"

# Verify video is accessible
uri = URI(video_url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
response = http.head(uri.path)

if response.code == '200'
  puts "✅ Video file is accessible (#{response['content-length'].to_i / 1024 / 1024} MB)"
else
  puts "❌ Video file not accessible: #{response.code}"
  exit 1
end

# Create URL_INPUT ingress
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
  input_type: "URL_INPUT",
  name: "URL Stream: #{video.title}",
  room_name: video.room_name,
  url: video_url,
  participant_identity: "video_player_#{video.video_id}",
  participant_name: "Video Player",
  bypass_transcoding: false,
  enable_transcoding: true,
  video: {
    source: "VIDEO_SOURCE_SCREEN_SHARE",
    preset: "H264_1080P_30FPS_3_LAYERS"
  },
  audio: {
    source: "AUDIO_SOURCE_MICROPHONE", 
    preset: "OPUS_STEREO_96KBPS"
  }
}

puts "\nCreating URL_INPUT ingress..."
request.body = request_body.to_json

response = http.request(request)

if response.code == '200'
  data = JSON.parse(response.body)
  ingress_id = data['ingress_id'] || data['ingressId']
  
  puts "\n✅ URL_INPUT Ingress Created Successfully!"
  puts "="*60
  
  # Update video record
  video.update!(
    ingress_id: ingress_id,
    ingress_url: video_url,
    streaming_active: true,
    streaming_status: data['state'] ? data['state']['status'] : 'STARTING'
  )
  
  puts "Ingress ID: #{ingress_id}"
  puts "Initial Status: #{data['state']['status']}"
  puts "="*60
  
  # Monitor ingress status
  puts "\nMonitoring stream status..."
  
  10.times do |i|
    sleep(3)
    
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
        error = ingress['state']['error']
        
        tracks = ingress['state']['tracks'] || []
        
        puts "[#{i+1}/10] Status: #{status}"
        
        if !tracks.empty?
          puts "  Tracks:"
          tracks.each do |track|
            puts "    - #{track['type']}: #{track['status']}"
          end
        end
        
        if status == 'ENDPOINT_ACTIVE'
          puts "\n🎉 SUCCESS! Video is now streaming from URL!"
          puts "\nStream Details:"
          puts "  - LiveKit is pulling video from: #{video_url}"
          puts "  - Streaming to room: #{video.room_name}"
          puts "  - Participant: #{data['participant_name']}"
          puts "\nTo view the stream:"
          puts "  1. Generate viewer token: POST /videos/#{video.video_id}/play"
          puts "  2. Connect to: wss://livekit.lovedrop.live"
          puts "  3. Join room: #{video.room_name}"
          
          # Generate a sample viewer token
          viewer_payload = {
            iss: api_key,
            exp: Time.now.to_i + 3600,
            sub: "viewer_test",
            name: "Test Viewer",
            video: {
              room: video.room_name,
              roomJoin: true,
              canSubscribe: true,
              canPublish: false
            },
            metadata: { role: 'viewer' }.to_json
          }
          
          viewer_token = JWT.encode(viewer_payload, api_secret, 'HS256')
          
          puts "\nSample viewer token for testing:"
          puts viewer_token
          
          break
        elsif status == 'ENDPOINT_ERROR'
          puts "\n❌ Streaming error: #{error}"
          break
        elsif status == 'ENDPOINT_BUFFERING'
          puts "  ⏳ LiveKit is fetching and buffering the video..."
        elsif status == 'ENDPOINT_PUBLISHING'
          puts "  📡 Publishing stream to room..."
        end
      end
    end
  end
  
  puts "\n" + "="*60
  puts "Test Complete!"
  puts "Ingress ID: #{ingress_id}"
  puts "\nTo stop streaming:"
  puts "  rails runner \"LivekitService.delete_ingress('#{ingress_id}')\""
  
else
  puts "\n❌ Failed to create ingress"
  error = JSON.parse(response.body) rescue {}
  puts "Error: #{error['msg'] || response.body}"
end