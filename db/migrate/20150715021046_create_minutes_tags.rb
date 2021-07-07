class CreateMinutesTags < ActiveRecord::Migration[4.2]
  def change
    create_table :minutes_tags, id: false do |t|
      t.references :minute, index: true, foreign_key: true, null: false
      t.references :tag, index: true, foreign_key: true, null: false
    end
  end
end
