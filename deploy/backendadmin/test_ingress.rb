#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'jwt'

api_key = 'd2493690c7c87be587586ebf10cfeaeb'
api_secret = 'PXRsXXfyXZjl1SsfUbN3Z+gsWhNxCG/6N49F6pNVknY='

# Create JWT token
payload = {
  iss: api_key,
  exp: Time.now.to_i + 3600
}

token = JWT.encode(payload, api_secret, 'HS256')

# List ingresses
uri = URI('https://livekit.lovedrop.live/twirp/livekit.Ingress/ListIngress')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Authorization'] = "Bearer #{token}"
request['Content-Type'] = 'application/json'
request.body = {}.to_json

puts "Testing LiveKit Ingress API..."
puts "Listing current ingresses..."

response = http.request(request)
puts "Response Code: #{response.code}"
puts "Response Body: #{response.body}"

if response.code == '200'
  data = JSON.parse(response.body)
  if data['items'] && data['items'].any?
    puts "\nActive Ingresses:"
    data['items'].each do |ingress|
      puts "- ID: #{ingress['ingressId']}"
      puts "  Name: #{ingress['name']}"
      puts "  Room: #{ingress['roomName']}"
      puts "  State: #{ingress['state']['status']}"
    end
  else
    puts "\nNo active ingresses found."
  end
  
  puts "\n✅ Ingress API is working!"
else
  puts "\n❌ Ingress API error: #{response.code}"
end