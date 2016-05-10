class CreateMeetingTypesTable < ActiveRecord::Migration
  def up
  	create_table :meeting_types do |t|
      t.string :name 
    end
  end

  def down
  	drop_table :meeting_types
  end
end
