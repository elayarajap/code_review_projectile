class RemoveActionItemFromMeetings < ActiveRecord::Migration
  def up
    remove_column :meetings, :action_items
  end

  def down
    add_column :meetings, :action_items, :string
  end
end
