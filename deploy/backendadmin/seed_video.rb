#!/usr/bin/env ruby

# Create a test video for streaming
video = Video.create!(
  video_id: "test_video_001",
  title: "Test Video",
  room_name: "test-room-#{SecureRandom.hex(4)}",
  streaming_mode: :on_demand,
  file_size: 1024 * 1024 * 10, # 10MB dummy size
  duration_seconds: 60
)

puts "Created video:"
puts "  ID: #{video.video_id}"
puts "  Title: #{video.title}"
puts "  Room: #{video.room_name}"
puts "  Mode: #{video.streaming_mode}"