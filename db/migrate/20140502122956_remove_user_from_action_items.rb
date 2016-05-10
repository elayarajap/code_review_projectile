class RemoveUserFromActionItems < ActiveRecord::Migration
  def up
    remove_column :action_items, :user
  end

  def down
    add_column :action_items, :user, :string
  end
end
