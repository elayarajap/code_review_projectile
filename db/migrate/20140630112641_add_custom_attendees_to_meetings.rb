class AddCustomAttendeesToMeetings < ActiveRecord::Migration
  def change
    #add_column :meetings, :custom_attendees, :string
    add_column :meetings, :end_date, :string
    add_column :meetings, :end_time, :string
  end
end
