class CreateMeetingsTable < ActiveRecord::Migration
  def up
  	create_table :meetings do |t|
      t.integer :project_id, :null => false
      t.integer :meeting_type_id, :null => false
      t.string :title
      t.string :discussion_summary
      t.date :date
      t.float :time 
    end
  end

  def down
  	drop_table :meetings
  end
end
