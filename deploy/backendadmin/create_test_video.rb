Video.create!(
  video_id: "test_hls_video",
  title: "Test HLS Video", 
  room_name: "test-hls-room",
  file_extension: "mp4",
  file_size: 1024000,  # 1MB placeholder
  streaming_mode: :on_demand,
  uploaded_at: Time.current,
  hls_ready: true,
  hls_path: "/videos/test_hls_video/hls",
  transcoding_status: "completed"
)
puts "Created test video with HLS settings"