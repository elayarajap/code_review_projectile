class AddBillableAndNonBillableToIssues < ActiveRecord::Migration
  def change
    add_column :issues, :billable, :float, :default => 0
    add_index :issues, :billable
    add_column :issues, :non_billable, :float, :default => 0
    add_index :issues, :non_billable
  end
end
