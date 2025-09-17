#!/usr/bin/env ruby
require_relative 'config/environment'
require 'net/http'
require 'json'
require 'jwt'

# First, let's create a test MP4 file if it doesn't exist
video_dir = Rails.root.join('public', 'videos')
FileUtils.mkdir_p(video_dir)

# Create a test video entry
video = Video.create!(
  video_id: "test_url_#{Time.now.to_i}",
  title: "URL Input Test Video",
  room_name: "test_url_room_#{Time.now.to_i}",
  file_size: 1024000,
  uploaded_at: Time.current
)

puts "Created test video: #{video.title}"
puts "Video ID: #{video.video_id}"
puts "Room Name: #{video.room_name}"

# The URL where the video would be accessible
video_url = "https://admin.livekit.lovedrop.live/videos/#{video.video_id}.mp4"
puts "Video URL: #{video_url}"

# Test URL_INPUT ingress creation
api_key = 'd2493690c7c87be587586ebf10cfeaeb'
api_secret = 'PXRsXXfyXZjl1SsfUbN3Z+gsWhNxCG/6N49F6pNVknY='

# Create ingress admin token
payload = {
  iss: api_key,
  exp: Time.now.to_i + 3600,
  video: {
    ingressAdmin: true
  }
}

token = JWT.encode(payload, api_secret, 'HS256')

# Use a test video URL that actually exists
test_video_url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

uri = URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/CreateIngress')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'

# URL_INPUT is type 3 according to LiveKit proto definitions
request_body = {
  input_type: 3,  # URL_INPUT = 3
  name: "URL Stream: #{video.title}",
  room_name: video.room_name,
  url: test_video_url,  # Using test URL that exists
  participant_identity: "url_streamer_#{video.video_id}",
  participant_name: "URL Video Stream",
  bypass_transcoding: false,
  enable_transcoding: true,
  video: {
    source: 0,  # SCREEN_SHARE
    preset: "H264_1080P_30FPS_3_LAYERS"  # Simulcast preset
  },
  audio: {
    source: 0,  # MICROPHONE
    preset: "OPUS_STEREO_96KBPS"
  }
}

puts "\n Testing URL_INPUT ingress creation..."
puts "Using test video URL: #{test_video_url}"

request.body = request_body.to_json

response = http.request(request)
puts "\nResponse Code: #{response.code}"

if response.code == '200'
  data = JSON.parse(response.body)
  
  puts "\n✅ URL_INPUT Ingress created successfully!"
  puts "\nFull response:"
  puts JSON.pretty_generate(data)
  
  ingress_id = data['ingress_id'] || data['ingressId']
  state = data['state']
  
  # Update video record
  video.update!(
    ingress_id: ingress_id,
    ingress_url: test_video_url,
    streaming_active: true,
    streaming_status: state ? state['status'] : 'STARTING'
  )
  
  puts "\nIngress Details:"
  puts "- Ingress ID: #{ingress_id}"
  puts "- Room: #{video.room_name}"
  puts "- State: #{state['status']}" if state
  puts "- URL: #{test_video_url}"
  
  puts "\n LiveKit should now be pulling and streaming the video from the URL"
  puts "The video will be available in room: #{video.room_name}"
  
  # Wait a moment and check status
  sleep(3)
  
  # Check ingress status
  list_request = Net::HTTP::Post.new(URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/ListIngress'))
  list_request['Authorization'] = "Bearer #{token}"
  list_request['Content-Type'] = 'application/json'
  list_request.body = { ingress_id: ingress_id }.to_json
  
  list_response = http.request(list_request)
  if list_response.code == '200'
    list_data = JSON.parse(list_response.body)
    if list_data['items'] && list_data['items'].any?
      ingress = list_data['items'].first
      puts "\n Current ingress status after 3 seconds:"
      puts "- State: #{ingress['state']['status']}"
      puts "- Error: #{ingress['state']['error']}" if ingress['state']['error'] && !ingress['state']['error'].empty?
      
      if ingress['state']['status'] == 'ENDPOINT_ACTIVE'
        puts "\n🎉 URL_INPUT streaming is ACTIVE!"
        puts "Video is being streamed from URL to LiveKit room"
      elsif ingress['state']['status'] == 'ENDPOINT_BUFFERING'
        puts "\n⏳ URL_INPUT is buffering/starting..."
        puts "LiveKit is fetching and processing the video"
      elsif ingress['state']['status'] == 'ENDPOINT_ERROR'
        puts "\n❌ URL_INPUT encountered an error"
        puts "Error: #{ingress['state']['error']}"
      end
    end
  end
  
else
  puts "\n❌ Failed to create URL_INPUT ingress"
  puts "Response: #{response.body}"
  
  error_data = JSON.parse(response.body) rescue {}
  if error_data['msg']
    puts "Error message: #{error_data['msg']}"
    
    if error_data['msg'].include?('invalid ingress type')
      puts "\n⚠️  URL_INPUT may not be supported in the current LiveKit deployment"
      puts "This feature requires LiveKit Ingress with URL input support enabled"
    end
  end
end