class CreateCustomAttendees < ActiveRecord::Migration
  def change
    create_table :custom_attendees do |t|
      t.string :name
      t.string :email
      t.integer :meeting_id

      t.timestamps
    end
  end
end
