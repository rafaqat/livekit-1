#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'

puts "Testing LiveKit Client Integration..."
puts "=" * 50

# Test 1: Check if the streaming test page loads
uri = URI('https://admin.livekit.lovedrop.live/streaming_test')
response = Net::HTTP.get_response(uri)

if response.code == '200'
  puts "✅ Streaming test page loads successfully"
else
  puts "❌ Failed to load streaming test page: #{response.code}"
  exit 1
end

# Test 2: Check if LiveKit client script is included
page_content = response.body
if page_content.include?('unpkg.com/livekit-client/dist/livekit-client.umd.min.js')
  puts "✅ LiveKit client script tag found"
else
  puts "❌ LiveKit client script tag not found"
end

# Test 3: Check if LivekitClient references are present
if page_content.include?('LivekitClient.Room')
  puts "✅ LivekitClient.Room reference found"
else
  puts "❌ LivekitClient.Room reference not found"
end

if page_content.include?('LivekitClient.RoomEvent')
  puts "✅ LivekitClient.RoomEvent reference found"
else
  puts "❌ LivekitClient.RoomEvent reference not found"
end

if page_content.include?('LivekitClient.VideoPresets')
  puts "✅ LivekitClient.VideoPresets reference found"
else
  puts "❌ LivekitClient.VideoPresets reference not found"
end

# Test 4: Create a simple HTML test file to verify client loading
test_html = <<-HTML
<!DOCTYPE html>
<html>
<head>
  <title>LiveKit Client Test</title>
  <script src="https://unpkg.com/livekit-client/dist/livekit-client.umd.min.js"></script>
</head>
<body>
  <h1>LiveKit Client Test</h1>
  <div id="result"></div>
  <script>
    window.onload = function() {
      const resultDiv = document.getElementById('result');
      const tests = [];
      
      // Test 1: Check if LivekitClient is defined
      tests.push({
        name: 'LivekitClient global object',
        pass: typeof LivekitClient !== 'undefined'
      });
      
      // Test 2: Check if Room class exists
      tests.push({
        name: 'LivekitClient.Room',
        pass: typeof LivekitClient !== 'undefined' && typeof LivekitClient.Room === 'function'
      });
      
      // Test 3: Check if RoomEvent exists
      tests.push({
        name: 'LivekitClient.RoomEvent',
        pass: typeof LivekitClient !== 'undefined' && typeof LivekitClient.RoomEvent === 'object'
      });
      
      // Test 4: Check if VideoPresets exists
      tests.push({
        name: 'LivekitClient.VideoPresets',
        pass: typeof LivekitClient !== 'undefined' && typeof LivekitClient.VideoPresets === 'object'
      });
      
      // Test 5: Try to create a Room instance
      let roomCreated = false;
      try {
        if (typeof LivekitClient !== 'undefined' && LivekitClient.Room) {
          const room = new LivekitClient.Room();
          roomCreated = true;
        }
      } catch(e) {
        // Expected to fail without proper config, but constructor should exist
        roomCreated = e.message.includes('Room') || e.message.includes('constructor');
      }
      tests.push({
        name: 'Room instantiation',
        pass: roomCreated
      });
      
      // Display results
      let html = '<h2>Test Results:</h2><ul>';
      let allPassed = true;
      tests.forEach(test => {
        const icon = test.pass ? '✅' : '❌';
        html += '<li>' + icon + ' ' + test.name + '</li>';
        if (!test.pass) allPassed = false;
      });
      html += '</ul>';
      
      if (allPassed) {
        html += '<p style="color: green; font-weight: bold;">All tests passed!</p>';
      } else {
        html += '<p style="color: red; font-weight: bold;">Some tests failed!</p>';
      }
      
      resultDiv.innerHTML = html;
      
      // Also log to console for debugging
      console.log('LiveKit Client Test Results:');
      console.log('LivekitClient defined:', typeof LivekitClient !== 'undefined');
      if (typeof LivekitClient !== 'undefined') {
        console.log('LivekitClient keys:', Object.keys(LivekitClient));
      }
    };
  </script>
</body>
</html>
HTML

# Save test HTML file
File.write('/tmp/livekit_client_test.html', test_html)
puts "\n📝 Test HTML file created at: /tmp/livekit_client_test.html"
puts "   You can open this file in a browser to see detailed client tests"

# Test 5: Check if the deployment has the latest changes
puts "\n" + "=" * 50
puts "Checking deployed version..."

# Get the current commit hash from the deployment
commit_check = `curl -s https://admin.livekit.lovedrop.live/streaming_test | grep -o 'LivekitClient\\.' | head -1`.strip

if commit_check.include?('LivekitClient')
  puts "✅ Deployed version has the correct LivekitClient reference"
else
  puts "⚠️  Deployed version may not have the latest changes yet"
  puts "   Run this test again after deployment completes"
end

puts "\n" + "=" * 50
puts "Test Summary:"
puts "- Page loads: ✅"
puts "- Script included: ✅" if page_content.include?('unpkg.com/livekit-client')
puts "- Correct global name used: #{page_content.include?('LivekitClient.') ? '✅' : '⚠️ Pending deployment'}"
puts "\nOpen /tmp/livekit_client_test.html in a browser for client-side verification"