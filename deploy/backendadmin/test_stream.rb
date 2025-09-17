#!/usr/bin/env ruby
require_relative 'config/environment'

# Create a test video entry
video = Video.create!(
  video_id: "test_video_#{Time.now.to_i}",
  title: "Test Video Stream",
  room_name: "test_room_#{Time.now.to_i}",
  file_size: 1024000,
  uploaded_at: Time.current
)

puts "Created test video: #{video.title}"
puts "Video ID: #{video.video_id}"
puts "Room Name: #{video.room_name}"

# Test streaming with a sample video URL
require 'net/http'
require 'json'
require 'jwt'

api_key = 'd2493690c7c87be587586ebf10cfeaeb'
api_secret = 'PXRsXXfyXZjl1SsfUbN3Z+gsWhNxCG/6N49F6pNVknY='

# Create ingress
payload = {
  iss: api_key,
  exp: Time.now.to_i + 3600,
  video: {
    ingressAdmin: true
  }
}

token = JWT.encode(payload, api_secret, 'HS256')

# Use a sample video URL for testing
sample_video_url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

uri = URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/CreateIngress')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'

# Try RTMP input type instead
rtmp_url = "rtmp://livekit.lovedrop.live/live/#{video.video_id}"

request_body = {
  input_type: 0,  # RTMP_INPUT = 0
  name: "Stream for #{video.title}",
  room_name: video.room_name,
  participant_identity: "streamer_#{video.video_id}",
  participant_name: "Video Streamer",
  bypass_transcoding: false,
  video: {
    source: 0,  # SCREEN_SHARE
    preset: 0   # H264_720P_30
  },
  audio: {
    source: 0,  # MICROPHONE
    preset: 0   # OPUS_STEREO_96KBPS
  }
}

puts "Note: Using RTMP input type since URL input may not be available"

request.body = request_body.to_json

puts "\nCreating ingress for video streaming..."
puts "Using sample video URL: #{sample_video_url}"

response = http.request(request)
puts "\nResponse Code: #{response.code}"

if response.code == '200'
  data = JSON.parse(response.body)
  
  puts "\n✅ Ingress created successfully!"
  puts "Full response: #{JSON.pretty_generate(data)}"
  
  ingress_id = data['ingress_id'] || data['ingressId'] 
  stream_key = data['stream_key'] || data['streamKey']
  url = data['url'] 
  state = data['state']
  
  puts "\nIngress Details:"
  puts "- Ingress ID: #{ingress_id}"
  puts "- Stream Key: #{stream_key}" if stream_key
  puts "- RTMP URL: #{url}" if url
  puts "- State: #{state['status']}" if state
  
  # Update video record
  video.update!(
    ingress_id: ingress_id,
    ingress_url: url || rtmp_url,
    streaming_active: true,
    streaming_status: state ? state['status'] : 'STARTING'
  )
  
  puts "\nVideo record updated with ingress details"
  puts "You can now view the stream in room: #{video.room_name}"
  
  # Check ingress status
  sleep(2)
  
  list_request = Net::HTTP::Post.new(URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/ListIngress'))
  list_request['Authorization'] = "Bearer #{token}"
  list_request['Content-Type'] = 'application/json'
  list_request.body = { roomName: video.room_name }.to_json
  
  list_response = http.request(list_request)
  if list_response.code == '200'
    list_data = JSON.parse(list_response.body)
    if list_data['items'] && list_data['items'].any?
      ingress = list_data['items'].first
      puts "\nCurrent ingress status:"
      puts "- State: #{ingress['state']['status']}"
      puts "- Room: #{ingress['roomName']}"
      puts "- Started At: #{Time.at(ingress['state']['startedAt'].to_i) if ingress['state']['startedAt']}"
    end
  end
  
else
  puts "\n❌ Failed to create ingress"
  puts "Response: #{response.body}"
  
  error_data = JSON.parse(response.body) rescue {}
  if error_data['msg']
    puts "Error message: #{error_data['msg']}"
  end
end