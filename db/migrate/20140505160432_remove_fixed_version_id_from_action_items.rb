class RemoveFixedVersionIdFromActionItems < ActiveRecord::Migration
  def up
    remove_column :action_items, :fixed_version_id
  end

  def down
    add_column :action_items, :fixed_version_id, :string
  end
end
