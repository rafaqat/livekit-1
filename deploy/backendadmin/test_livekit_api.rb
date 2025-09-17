#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'jwt'

api_key = 'd2493690c7c87be587586ebf10cfeaeb'
api_secret = 'PXRsXXfyXZjl1SsfUbN3Z+gsWhNxCG/6N49F6pNVknY='

# Create JWT token for room list
payload = {
  iss: api_key,
  exp: Time.now.to_i + 3600,
  video: {
    roomList: true
  }
}

token = JWT.encode(payload, api_secret, 'HS256')

# List rooms
uri = URI('https://livekit.lovedrop.live/twirp/livekit.RoomService/ListRooms')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'
request.body = {}.to_json

puts "Testing LiveKit Room API..."
response = http.request(request)
puts "Response Code: #{response.code}"
puts "Response Body: #{response.body}"

if response.code == '200'
  puts "\n✅ LiveKit API authentication is working!"
  
  # Now test ingress with proper permissions
  ingress_payload = {
    iss: api_key,
    exp: Time.now.to_i + 3600,
    video: {
      ingressAdmin: true
    }
  }
  
  ingress_token = JWT.encode(ingress_payload, api_secret, 'HS256')
  
  # List ingresses
  uri = URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/ListIngress')
  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{ingress_token}"
  request['Content-Type'] = 'application/json'
  request.body = {}.to_json
  
  puts "\nTesting LiveKit Ingress API..."
  response = http.request(request)
  puts "Response Code: #{response.code}"
  puts "Response Body: #{response.body}"
  
  if response.code == '200'
    puts "\n✅ Ingress API is working!"
  else
    puts "\n❌ Ingress API error"
  end
else
  puts "\n❌ LiveKit API authentication failed"
end