class AddUserIdToActionItems < ActiveRecord::Migration

 def up
 	add_column :action_items, :user_id, :integer
 end

  def down
   remove_column :meetings, :action_item
  end
 
end
