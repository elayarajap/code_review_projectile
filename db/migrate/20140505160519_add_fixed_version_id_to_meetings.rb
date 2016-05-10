class AddFixedVersionIdToMeetings < ActiveRecord::Migration
  def change
    add_column :meetings, :fixed_version_id, :string
  end
end
