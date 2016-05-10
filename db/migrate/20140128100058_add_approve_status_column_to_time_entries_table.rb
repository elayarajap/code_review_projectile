class AddApproveStatusColumnToTimeEntriesTable < ActiveRecord::Migration
  def change
  	add_column :time_entries, :approval_status, :tinyint, :default => nil, :limit=> 1
  end
end
