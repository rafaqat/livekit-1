#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'jwt'

api_key = 'd2493690c7c87be587586ebf10cfeaeb'
api_secret = 'PXRsXXfyXZjl1SsfUbN3Z+gsWhNxCG/6N49F6pNVknY='

# Create token with room list permission
payload = {
  iss: api_key,
  exp: Time.now.to_i + 3600,
  video: {
    roomList: true,
    roomRecord: true,
    room: "room_demo_1757772661",
    roomJoin: true
  }
}

token = JWT.encode(payload, api_secret, 'HS256')

# List all rooms
uri = URI('https://livekit.lovedrop.live/twirp/livekit.RoomService/ListRooms')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'
request.body = {}.to_json

puts "Checking LiveKit rooms..."
response = http.request(request)

if response.code == '200'
  data = JSON.parse(response.body)
  rooms = data['rooms'] || []
  
  if rooms.empty?
    puts "No active rooms found"
  else
    puts "\nActive Rooms:"
    puts "="*60
    
    rooms.each do |room|
      puts "\nRoom: #{room['name']}"
      puts "  SID: #{room['sid']}"
      puts "  Participants: #{room['num_participants']}"
      puts "  Created: #{Time.at(room['creation_time'].to_i)}"
      
      if room['num_participants'] > 0
        # Get room participants
        part_uri = URI('https://livekit.lovedrop.live/twirp/livekit.RoomService/ListParticipants')
        part_request = Net::HTTP::Post.new(part_uri)
        part_request['Authorization'] = "Bearer #{token}"
        part_request['Content-Type'] = 'application/json'
        part_request.body = { room: room['name'] }.to_json
        
        part_response = http.request(part_request)
        if part_response.code == '200'
          part_data = JSON.parse(part_response.body)
          participants = part_data['participants'] || []
          
          puts "\n  Participants:"
          participants.each do |p|
            puts "    - #{p['identity']} (#{p['name']})"
            puts "      State: #{p['state']}"
            puts "      Tracks:"
            
            tracks = p['tracks'] || []
            tracks.each do |track|
              puts "        - #{track['type']}: #{track['name']} (#{track['muted'] ? 'muted' : 'active'})"
            end
          end
        end
      end
    end
  end
  
  # Check specific room
  room_name = "room_demo_1757772661"
  puts "\n" + "="*60
  puts "Checking specific room: #{room_name}"
  
  room_uri = URI('https://livekit.lovedrop.live/twirp/livekit.RoomService/ListParticipants')
  room_request = Net::HTTP::Post.new(room_uri)
  room_request['Authorization'] = "Bearer #{token}"
  room_request['Content-Type'] = 'application/json'
  room_request.body = { room: room_name }.to_json
  
  room_response = http.request(room_request)
  if room_response.code == '200'
    room_data = JSON.parse(room_response.body)
    participants = room_data['participants'] || []
    
    if participants.empty?
      puts "Room exists but has no participants (ingress may still be connecting)"
    else
      puts "✅ Room has #{participants.length} participant(s)"
      participants.each do |p|
        puts "\nParticipant: #{p['identity']}"
        puts "  Name: #{p['name']}"
        puts "  Tracks:"
        (p['tracks'] || []).each do |track|
          puts "    - #{track['type']}: #{track['source']} (#{track['muted'] ? 'muted' : 'active'})"
        end
      end
    end
  elsif room_response.code == '404'
    puts "Room does not exist yet"
  else
    puts "Error checking room: #{room_response.code}"
  end
else
  puts "Failed to list rooms: #{response.code}"
  puts response.body
end