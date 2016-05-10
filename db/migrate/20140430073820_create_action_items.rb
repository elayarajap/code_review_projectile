class CreateActionItems < ActiveRecord::Migration
  def change
    create_table :action_items do |t|
      t.string :item
      t.string :user
      t.references :meeting

      t.timestamps
    end
    add_index :action_items, :meeting_id
  end
end
