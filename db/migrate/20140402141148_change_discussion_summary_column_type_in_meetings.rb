class ChangeDiscussionSummaryColumnTypeInMeetings < ActiveRecord::Migration
  def up
  	change_column :meetings, :discussion_summary, :text
  end

  def down
  	change_column :meetings, :discussion_summary, :varchar
  end
end
