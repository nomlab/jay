class CreateMinutes < ActiveRecord::Migration[4.2]
  def change
    create_table :minutes do |t|
      t.string :title
      t.datetime :dtstart
      t.datetime :dtend
      t.string :location
      t.integer :author_id
      t.text :content

      t.timestamps null: false
    end
  end
end
