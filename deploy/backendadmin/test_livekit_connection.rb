#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'
require 'base64'

puts "Testing LiveKit Connection and Streaming..."
puts "=" * 50

# Step 1: Check if streaming test page loads
uri = URI('https://admin.livekit.lovedrop.live/streaming_test')
response = Net::HTTP.get_response(uri)

if response.code == '200'
  puts "✅ Streaming test page loads successfully"
else
  puts "❌ Failed to load streaming test page: #{response.code}"
  exit 1
end

# Step 2: Check if the correct CDN is being used
page_content = response.body
if page_content.include?('cdn.jsdelivr.net/npm/livekit-client')
  puts "✅ Using jsdelivr CDN for LiveKit client"
else
  puts "❌ Not using jsdelivr CDN"
end

# Step 3: Check global references
livekitclient_refs = page_content.scan(/LivekitClient\.\w+/).uniq
if livekitclient_refs.any?
  puts "✅ LivekitClient references found: #{livekitclient_refs.first(3).join(', ')}..."
else
  puts "❌ No LivekitClient references found"
end

# Step 4: Test token generation endpoint
puts "\n" + "=" * 50
puts "Testing Token Generation..."

# Get a test video ID from the page
video_id_match = page_content.match(/data-video-id="([^"]+)"/)
if video_id_match
  video_id = video_id_match[1]
  puts "Found test video: #{video_id}"
  
  # Test the streaming endpoint
  test_uri = URI('https://admin.livekit.lovedrop.live/streaming_test/test_stream')
  http = Net::HTTP.new(test_uri.host, test_uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Post.new(test_uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    video_id: video_id,
    test_config: {
      quality: 'auto',
      network: 'excellent',
      codec: 'h264',
      client_type: 'web'
    }
  }.to_json
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    
    if data['connection'] && data['connection']['token']
      puts "✅ Token generated successfully"
      
      # Decode and verify token structure
      token_parts = data['connection']['token'].split('.')
      if token_parts.length == 3
        begin
          # Decode the payload (base64url decode)
          payload = JSON.parse(Base64.urlsafe_decode64(token_parts[1]))
          
          puts "\nToken payload structure:"
          puts "  - Issuer (iss): #{payload['iss'] ? '✅' : '❌'}"
          puts "  - Subject (sub): #{payload['sub'] ? '✅' : '❌'}"
          puts "  - Video grants: #{payload['video'] ? '✅' : '❌'}"
          
          if payload['video']
            puts "    - Room: #{payload['video']['room']}"
            puts "    - Can subscribe: #{payload['video']['canSubscribe']}"
          end
          
          if payload['sub']
            puts "✅ JWT token has correct structure with 'sub' field"
          else
            puts "❌ JWT token missing 'sub' field for participant identity"
          end
          
        rescue => e
          puts "⚠️  Could not decode token payload: #{e.message}"
        end
      else
        puts "❌ Invalid token format"
      end
      
      puts "\nConnection details:"
      puts "  - WebSocket URL: #{data['connection']['websocket_url']}"
      puts "  - Room name: #{data['connection']['room_name']}"
      
      if data['video']
        puts "\nVideo details:"
        puts "  - Title: #{data['video']['title']}"
        puts "  - Streaming active: #{data['video']['streaming_active']}"
        puts "  - Ingress ID: #{data['video']['ingress_id'] || 'Not started'}"
      end
      
    else
      puts "❌ No token in response"
    end
  else
    puts "❌ Failed to get test token: #{response.code}"
    puts "Response: #{response.body}"
  end
else
  puts "⚠️  No test videos found on page"
end

# Step 5: Test LiveKit WebSocket connectivity
puts "\n" + "=" * 50
puts "Testing LiveKit Server Connectivity..."

# Try to connect to the WebSocket endpoint (just check if it's reachable)
ws_uri = URI('https://livekit.lovedrop.live/rtc')
ws_response = Net::HTTP.get_response(ws_uri)

# We expect a 404 or 426 for HTTP request to WebSocket endpoint
if ws_response.code == '404' || ws_response.code == '426'
  puts "✅ LiveKit WebSocket endpoint is reachable"
elsif ws_response.code == '200'
  puts "⚠️  Unexpected response from WebSocket endpoint"
else
  puts "❌ LiveKit server may not be accessible: #{ws_response.code}"
end

# Final summary
puts "\n" + "=" * 50
puts "Test Summary:"
puts "- Page loads: ✅"
puts "- CDN configured: ✅" if page_content.include?('cdn.jsdelivr.net')
puts "- LivekitClient references: ✅" if livekitclient_refs.any?
puts "- Token generation: Check results above"
puts "- Server connectivity: Check results above"

puts "\n✨ The LiveKit client should now be able to connect!"
puts "Test the streaming at: https://admin.livekit.lovedrop.live/streaming_test"