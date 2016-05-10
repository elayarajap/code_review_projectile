class AddHoursTypeToTimeEntriesTable < ActiveRecord::Migration
  def change
  	add_column :time_entries, :hours_type, :boolean, :default => 0
  end
end
