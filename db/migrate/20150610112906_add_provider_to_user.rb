class AddProviderToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :provider, :string
  end
end
