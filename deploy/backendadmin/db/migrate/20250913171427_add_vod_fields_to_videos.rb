class AddVodFieldsToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :streaming_mode, :integer, default: 0, null: false
    add_column :videos, :ingress_state, :integer, default: 0, null: false
    add_column :videos, :auto_restart, :boolean, default: false
    add_column :videos, :loop_video, :boolean, default: false
    add_column :videos, :total_views, :integer, default: 0
    add_column :videos, :total_watch_seconds, :integer, default: 0
    add_column :videos, :average_completion_rate, :float, default: 0.0
    add_column :videos, :duration_seconds, :integer
    
    add_index :videos, :streaming_mode
    add_index :videos, :ingress_state
  end
end
