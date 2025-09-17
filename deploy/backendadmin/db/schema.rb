# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_14_034917) do
  create_table "pins", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "address"
    t.string "status"
    t.string "user_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "videos", force: :cascade do |t|
    t.string "video_id", null: false
    t.string "title"
    t.text "description"
    t.string "original_filename"
    t.bigint "file_size"
    t.string "room_name", null: false
    t.string "ingress_id"
    t.string "ingress_url"
    t.string "stream_key"
    t.string "video_url"
    t.boolean "streaming_active", default: false
    t.string "streaming_status", default: "NOT_STARTED"
    t.datetime "uploaded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "streaming_mode", default: 0, null: false
    t.integer "ingress_state", default: 0, null: false
    t.boolean "auto_restart", default: false
    t.boolean "loop_video", default: false
    t.integer "total_views", default: 0
    t.integer "total_watch_seconds", default: 0
    t.float "average_completion_rate", default: 0.0
    t.integer "duration_seconds"
    t.string "file_extension"
    t.datetime "scheduled_start_at"
    t.datetime "scheduled_end_at"
    t.boolean "hls_ready", default: false
    t.string "hls_path"
    t.boolean "dash_ready", default: false
    t.string "dash_path"
    t.string "transcoding_status", default: "pending"
    t.integer "transcoding_progress", default: 0
    t.index ["ingress_state"], name: "index_videos_on_ingress_state"
    t.index ["room_name"], name: "index_videos_on_room_name"
    t.index ["streaming_mode"], name: "index_videos_on_streaming_mode"
    t.index ["video_id"], name: "index_videos_on_video_id", unique: true
  end

  create_table "viewing_sessions", force: :cascade do |t|
    t.integer "video_id", null: false
    t.string "viewer_identity", null: false
    t.string "viewer_ip"
    t.string "room_name"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "duration_seconds", default: 0
    t.integer "quality_switches", default: 0
    t.string "average_quality"
    t.float "average_bitrate"
    t.integer "buffering_events", default: 0
    t.integer "connection_drops", default: 0
    t.json "quality_timeline"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ended_at"], name: "index_viewing_sessions_on_ended_at"
    t.index ["started_at"], name: "index_viewing_sessions_on_started_at"
    t.index ["updated_at"], name: "index_viewing_sessions_on_updated_at"
    t.index ["video_id", "started_at"], name: "index_viewing_sessions_on_video_id_and_started_at"
    t.index ["video_id", "viewer_identity", "ended_at"], name: "index_viewing_sessions_on_video_viewer_end"
    t.index ["video_id"], name: "index_viewing_sessions_on_video_id"
    t.index ["viewer_identity"], name: "index_viewing_sessions_on_viewer_identity"
  end

  add_foreign_key "viewing_sessions", "videos"
end
