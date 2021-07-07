class CreateActionItems < ActiveRecord::Migration[4.2]
  def change
    create_table :action_items do |t|
      t.string :summary
      t.string :uid
      t.string :github_issue

      t.timestamps null: false
    end
    add_index :action_items, :github_issue, unique: true
  end
end
