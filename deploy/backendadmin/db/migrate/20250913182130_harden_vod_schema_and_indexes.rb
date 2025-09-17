class HardenVodSchemaAndIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add file extension and scheduling fields
    add_column :videos, :file_extension, :string
    add_column :videos, :scheduled_start_at, :datetime
    add_column :videos, :scheduled_end_at, :datetime

    # Enforce NOT NULL constraints where appropriate
    change_column_null :videos, :video_id, false
    change_column_null :videos, :room_name, false
    change_column_null :viewing_sessions, :viewer_identity, false

    # Indexes to support cleanup and lookups
    add_index :viewing_sessions, :ended_at
    add_index :viewing_sessions, :updated_at
    add_index :viewing_sessions, [:video_id, :viewer_identity, :ended_at], name: 'index_viewing_sessions_on_video_viewer_end'
  end
end

