#!/usr/bin/env ruby
require_relative 'config/environment'
require 'net/http'
require 'json'
require 'jwt'

video = Video.create!(
  video_id: "test_str_#{Time.now.to_i}",
  title: "URL String Test",
  room_name: "test_str_room_#{Time.now.to_i}",
  file_size: 1024000,
  uploaded_at: Time.current
)

puts "Testing with string-based input_type values..."

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
test_video_url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"

uri = URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/CreateIngress')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

# Try different variations
test_cases = [
  { input_type: "URL_INPUT", name: "String URL_INPUT" },
  { input_type: "FILE_INPUT", name: "String FILE_INPUT" },
  { input_type: 2, name: "Integer 2 (WHIP)" },
  { inputType: "URL_INPUT", name: "camelCase inputType" },
]

test_cases.each do |test_case|
  puts "\n Testing: #{test_case[:name]}..."
  
  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{token}"
  request['Content-Type'] = 'application/json'
  
  request_body = {
    name: "Test: #{test_case[:name]}",
    room_name: video.room_name,
    url: test_video_url,
    participant_identity: "test_#{video.video_id}",
    participant_name: "Test Stream",
    bypass_transcoding: false,
    enable_transcoding: true
  }
  
  # Add the input type using the test case key
  if test_case[:input_type]
    request_body[:input_type] = test_case[:input_type]
  elsif test_case[:inputType]
    request_body[:inputType] = test_case[:inputType]
  end
  
  request.body = request_body.to_json
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    puts "  ✅ SUCCESS! Input type '#{test_case[:name]}' worked"
    puts "  Ingress ID: #{data['ingress_id'] || data['ingressId']}"
    puts "  Type: #{data['input_type'] || data['inputType']}"
    
    # Clean up successful ingress
    if ingress_id = (data['ingress_id'] || data['ingressId'])
      delete_request = Net::HTTP::Post.new(URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/DeleteIngress'))
      delete_request['Authorization'] = "Bearer #{token}"
      delete_request['Content-Type'] = 'application/json'
      delete_request.body = { ingress_id: ingress_id }.to_json
      http.request(delete_request)
    end
    
    break # Found working format
  else
    error = JSON.parse(response.body) rescue {}
    puts "  ❌ Failed: #{error['msg'] || response.body}"
  end
end