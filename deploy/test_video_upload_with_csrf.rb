#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'
require 'tempfile'

puts "🎥 Testing Video Upload with CSRF Token"
puts "=" * 50

BASE_URL = "https://admin.livekit.lovedrop.live"

# Step 1: Get the upload form and extract CSRF token
puts "\n1. Getting CSRF token from upload form..."
uri = URI("#{BASE_URL}/videos/new")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri)
response = http.request(request)

if response.code != '200'
  puts "   ❌ Failed to get upload form: #{response.code}"
  exit 1
end

# Extract CSRF token from the form
csrf_token = nil
if response.body =~ /name="authenticity_token"\s+value="([^"]+)"/
  csrf_token = $1
  puts "   ✅ CSRF token obtained"
else
  puts "   ❌ Could not extract CSRF token"
  exit 1
end

# Extract session cookie
session_cookie = response['set-cookie']
if session_cookie
  session_cookie = session_cookie.split(';').first
  puts "   ✅ Session cookie obtained"
else
  puts "   ❌ Could not get session cookie"
  exit 1
end

# Step 2: Create a test video file
puts "\n2. Creating test video file..."
test_file = Tempfile.new(['test_video', '.mp4'])
# Create a minimal valid MP4 header
ftyp = [
  0x00, 0x00, 0x00, 0x20,  # box size
  0x66, 0x74, 0x79, 0x70,  # 'ftyp'
  0x69, 0x73, 0x6F, 0x6D,  # 'isom'
  0x00, 0x00, 0x02, 0x00,  # minor version
  0x69, 0x73, 0x6F, 0x6D,  # compatible brand
  0x69, 0x73, 0x6F, 0x32,  # compatible brand
  0x61, 0x76, 0x63, 0x31,  # compatible brand
  0x6D, 0x70, 0x34, 0x31   # compatible brand
].pack('C*')
test_file.write(ftyp)
test_file.write("0" * 1024)
test_file.rewind
puts "   ✅ Test video created: #{test_file.path}"

# Step 3: Upload the video with CSRF token
puts "\n3. Uploading video with CSRF protection..."
uri = URI("#{BASE_URL}/videos")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

boundary = "----WebKitFormBoundary#{rand(10000000000000000)}"
post_body = []

# Add CSRF token
post_body << "--#{boundary}\r\n"
post_body << "Content-Disposition: form-data; name=\"authenticity_token\"\r\n\r\n"
post_body << "#{csrf_token}\r\n"

# Add title
post_body << "--#{boundary}\r\n"
post_body << "Content-Disposition: form-data; name=\"title\"\r\n\r\n"
post_body << "Test Video #{Time.now.to_i}\r\n"

# Add description
post_body << "--#{boundary}\r\n"
post_body << "Content-Disposition: form-data; name=\"description\"\r\n\r\n"
post_body << "Automated test video upload\r\n"

# Add file
post_body << "--#{boundary}\r\n"
post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"test.mp4\"\r\n"
post_body << "Content-Type: video/mp4\r\n\r\n"
post_body << File.read(test_file.path)
post_body << "\r\n--#{boundary}--\r\n"

request = Net::HTTP::Post.new(uri.path)
request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
request["Cookie"] = session_cookie
request.body = post_body.join

response = http.request(request)

if response.code == '302' || response.code == '303'
  puts "   ✅ Video uploaded successfully!"
  redirect_location = response['Location']
  puts "   📍 Redirected to: #{redirect_location}"
  
  # Follow redirect to get video details
  if redirect_location
    video_uri = URI(redirect_location)
    video_uri = URI("#{BASE_URL}#{redirect_location}") unless redirect_location.start_with?('http')
    
    request = Net::HTTP::Get.new(video_uri)
    request["Cookie"] = session_cookie
    video_response = http.request(request)
    
    if video_response.code == '200'
      # Extract video ID from the page
      if video_response.body =~ /video_([a-f0-9]+)/
        video_id = "video_#{$1}"
        puts "   🎬 Video ID: #{video_id}"
        
        # Test streaming endpoint
        puts "\n4. Testing video streaming..."
        stream_uri = URI("#{BASE_URL}/videos/#{video_id}/play")
        request = Net::HTTP::Get.new(stream_uri)
        request["Cookie"] = session_cookie
        stream_response = http.request(request)
        
        if stream_response.code == '200'
          begin
            data = JSON.parse(stream_response.body)
            puts "   ✅ Streaming ready!"
            puts "   📡 Room: #{data['room_name']}" if data['room_name']
            puts "   🔑 Token: #{data['token'] ? 'Generated' : 'Not generated'}"
            puts "   🌐 WebSocket: #{data['websocket_url']}" if data['websocket_url']
          rescue JSON::ParserError
            puts "   ⚠️  Streaming endpoint returned non-JSON response"
          end
        else
          puts "   ❌ Streaming test failed: #{stream_response.code}"
        end
      end
    end
  end
elsif response.code == '422'
  puts "   ❌ Upload rejected (CSRF/validation error): #{response.code}"
  puts "   Response preview: #{response.body[0..500]}"
elsif response.code == '500'
  puts "   ❌ Server error: #{response.code}"
  puts "   This might indicate a database or processing issue"
else
  puts "   ❌ Upload failed: #{response.code}"
  puts "   Response: #{response.body[0..200]}"
end

# Clean up
test_file.close
test_file.unlink

puts "\n" + "=" * 50
puts "✅ Video Upload Test Complete!"
puts "=" * 50