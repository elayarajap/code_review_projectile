class AddFixedVersionIdAndDateToActionItem < ActiveRecord::Migration
  def change
    add_column :action_items, :fixed_version_id, :integer
    add_column :action_items, :date, :date
  end
end
