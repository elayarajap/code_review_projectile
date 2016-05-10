class AddAttendeesToMeetings < ActiveRecord::Migration
  def change
    add_column :meetings, :attendees, :string
  end
end
