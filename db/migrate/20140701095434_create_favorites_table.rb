class CreateFavoritesTable < ActiveRecord::Migration
  def up
  	create_table :favorites do |t|
      t.integer :user_id, :null => false
      t.integer :project_id, :null => false
  	end
  end

  def down
  	drop_table :favorites
  end
end
