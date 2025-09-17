#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bin/rails runner script/smoke_vod.rb

require "securerandom"

puts "[SMOKE] Starting VOD token/session smoke test..."

missing = %w[LIVEKIT_API_KEY LIVEKIT_API_SECRET LIVEKIT_SERVER_URL LIVEKIT_WS_URL].select { |k| ENV[k].to_s.empty? }
abort "[SMOKE] Missing ENV: #{missing.join(', ')}" unless missing.empty?

video = Video.create!(
  video_id: "smoke_#{SecureRandom.hex(4)}",
  title: "Smoke Test",
  description: "",
  original_filename: "test.mp4",
  file_size: 1024 * 1024 * 4, # 4 MB
  file_extension: "mp4",
  room_name: "room-smoke-#{SecureRandom.hex(4)}",
  video_url: "#{ENV["ASSET_BASE_URL"] || "http://localhost:3000"}/videos/test.mp4",
  uploaded_at: Time.current,
  streaming_mode: :on_demand
)

viewer_identity = "smoke-viewer-#{SecureRandom.hex(4)}"
session = ViewingSession.start_session(video, viewer_identity, "127.0.0.1", { smoke: true })

token = video.generate_viewing_token(viewer_identity, { ua: "smoke" }, session_id: session.id)
payload = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256', verify_expiration: true }).first

raise "[SMOKE] Token payload mismatch" unless payload["video_id"] == video.video_id && payload["viewer"] == viewer_identity && payload["session_id"].to_s == session.id.to_s

puts "[SMOKE] Token verified for video=#{video.video_id} session=#{session.id}"

# Simulate some session activity
session.track_quality_change("720p", "1080p")
session.track_buffering(350)
session.track_connection_drop("test-drop")
session.end_session(switches: 2, average_quality: "1080p", average_bitrate: 1800.5, buffering_events: 1, connection_drops: 1)

video.reload
puts "[SMOKE] Session ended. duration=#{session.duration_seconds}s views=#{video.total_views} completion=#{video.completion_rate}%"

puts "[SMOKE] OK"

