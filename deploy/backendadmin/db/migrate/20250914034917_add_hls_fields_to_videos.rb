class AddHlsFieldsToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :hls_ready, :boolean, default: false
    add_column :videos, :hls_path, :string
    add_column :videos, :dash_ready, :boolean, default: false
    add_column :videos, :dash_path, :string
    add_column :videos, :transcoding_status, :string, default: 'pending'
    add_column :videos, :transcoding_progress, :integer, default: 0
  end
end
