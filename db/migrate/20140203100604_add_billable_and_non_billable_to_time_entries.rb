class AddBillableAndNonBillableToTimeEntries < ActiveRecord::Migration
  def change
    add_column :time_entries, :billable, :float, :default => 0
    add_column :time_entries, :non_billable, :float, :default => 0
  end
end
