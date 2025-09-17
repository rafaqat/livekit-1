class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.string :video_id
      t.string :title
      t.text :description
      t.string :original_filename
      t.bigint :file_size
      t.string :room_name
      t.string :ingress_id
      t.string :ingress_url
      t.string :stream_key
      t.string :video_url
      t.boolean :streaming_active, default: false
      t.string :streaming_status, default: 'NOT_STARTED'
      t.datetime :uploaded_at

      t.timestamps
    end
    add_index :videos, :video_id, unique: true
    add_index :videos, :room_name
  end
end
