class CreateDirectoriesTable < ActiveRecord::Migration
  def up
  	create_table :directories do |t|
      t.column :project_id, :integer, :null => false
      t.column :name, :string,  :limit => 255, :null => false
    end
  end

  def down
  	drop_table :directories
  end
end