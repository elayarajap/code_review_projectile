class RemoveMeetingTypeIdFromMeetings < ActiveRecord::Migration
  def up
    remove_column :meetings, :meeting_type_id
  end

  def down
    add_column :meetings, :meeting_type_id, :integer
  end
end
