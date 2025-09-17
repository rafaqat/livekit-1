class CreateViewingSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :viewing_sessions do |t|
      t.references :video, null: false, foreign_key: true
      t.string :viewer_identity
      t.string :viewer_ip
      t.string :room_name
      t.datetime :started_at
      t.datetime :ended_at
      t.integer :duration_seconds, default: 0
      t.integer :quality_switches, default: 0
      t.string :average_quality
      t.float :average_bitrate
      t.integer :buffering_events, default: 0
      t.integer :connection_drops, default: 0
      t.json :quality_timeline
      t.json :metadata

      t.timestamps
    end
    
    add_index :viewing_sessions, :viewer_identity
    add_index :viewing_sessions, :started_at
    add_index :viewing_sessions, [:video_id, :started_at]
  end
end
