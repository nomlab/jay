class CreateActionItems < ActiveRecord::Migration
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
