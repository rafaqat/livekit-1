class CreatePins < ActiveRecord::Migration[8.0]
  def change
    create_table :pins do |t|
      t.string :title
      t.text :description
      t.decimal :latitude
      t.decimal :longitude
      t.string :address
      t.string :status
      t.string :user_name

      t.timestamps
    end
  end
end
