#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'jwt'

api_key = 'd2493690c7c87be587586ebf10cfeaeb'
api_secret = 'PXRsXXfyXZjl1SsfUbN3Z+gsWhNxCG/6N49F6pNVknY='

puts "=== LiveKit URL_INPUT Stream Status ==="
puts

# Check ingress status
ingress_payload = {
  iss: api_key,
  exp: Time.now.to_i + 3600,
  video: {
    ingressAdmin: true
  }
}

ingress_token = JWT.encode(ingress_payload, api_secret, 'HS256')

uri = URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/ListIngress')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{ingress_token}"
request['Content-Type'] = 'application/json'
request.body = {}.to_json

response = http.request(request)

if response.code == '200'
  data = JSON.parse(response.body)
  ingresses = data['items'] || []
  
  if ingresses.empty?
    puts "No active ingresses found"
  else
    puts "Active Ingresses:"
    puts "="*60
    
    ingresses.each do |ingress|
      puts "\nIngress: #{ingress['name']}"
      puts "  ID: #{ingress['ingress_id']}"
      puts "  Type: #{ingress['input_type']}"
      puts "  Room: #{ingress['room_name']}"
      puts "  Status: #{ingress['state']['status']}"
      
      if ingress['input_type'] == 'URL_INPUT'
        puts "  URL: #{ingress['url']}"
      end
      
      if ingress['state']['status'] == 'ENDPOINT_ACTIVE'
        puts "  ✅ STREAMING ACTIVE"
        started = ingress['state']['started_at']
        if started && started.to_i > 0
          duration = Time.now.to_i - (started.to_i / 1_000_000_000)
          puts "  Duration: #{duration} seconds"
        end
      elsif ingress['state']['status'] == 'ENDPOINT_PUBLISHING'
        puts "  📡 PUBLISHING TO ROOM"
      elsif ingress['state']['status'] == 'ENDPOINT_ERROR'
        puts "  ❌ ERROR: #{ingress['state']['error']}"
      end
      
      tracks = ingress['state']['tracks'] || []
      if !tracks.empty?
        puts "  Tracks:"
        tracks.each do |track|
          puts "    - #{track['type']}: #{track['status']}"
        end
      end
    end
  end
  
  puts "\n" + "="*60
  puts "\nSummary:"
  
  url_ingresses = ingresses.select { |i| i['input_type'] == 'URL_INPUT' }
  if url_ingresses.any?
    active = url_ingresses.select { |i| i['state']['status'] == 'ENDPOINT_ACTIVE' }
    publishing = url_ingresses.select { |i| i['state']['status'] == 'ENDPOINT_PUBLISHING' }
    
    puts "✅ #{url_ingresses.length} URL_INPUT ingress(es) found"
    puts "  - Active: #{active.length}"
    puts "  - Publishing: #{publishing.length}"
    
    if publishing.any?
      puts "\n⚠️  Note: ENDPOINT_PUBLISHING status means LiveKit is actively"
      puts "   fetching and transcoding the video. This is normal for URL_INPUT."
      puts "   The stream is available for viewers to connect."
    end
  else
    puts "No URL_INPUT ingresses found"
  end
else
  puts "Failed to list ingresses: #{response.code}"
end