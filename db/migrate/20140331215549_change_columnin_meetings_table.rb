class ChangeColumninMeetingsTable < ActiveRecord::Migration
  def self.up
   change_column :meetings, :date, :string
   change_column :meetings, :time, :string
  end

  def self.down
   change_column :meetings, :date, :date
   change_column :meetings, :time, :float
  end
end
