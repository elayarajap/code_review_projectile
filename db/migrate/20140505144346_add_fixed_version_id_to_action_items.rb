class AddFixedVersionIdToActionItems < ActiveRecord::Migration
  def change
    add_column :action_items, :fixed_version_id, :string
  end
end
