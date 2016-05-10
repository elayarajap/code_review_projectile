class AddActionitemsColumnMeetings < ActiveRecord::Migration
  def up
  	add_column :meetings, :action_items, :text
  end

  def down
  	remove_column :meetings, :action_items
  end
end
