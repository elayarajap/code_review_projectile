class ChangeColumnTypeInActionItem < ActiveRecord::Migration
  def self.up
   change_column :action_items, :date, :text
  end
 
  def self.down
   change_column :action_items, :date, :date
  end
end
