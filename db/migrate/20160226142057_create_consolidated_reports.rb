class CreateConsolidatedReports < ActiveRecord::Migration
  def change
    create_table :consolidated_reports do |t|
      t.integer :user_id
      t.integer :group_id
      t.string :group_name
      t.integer :account_id
      t.integer :project_id
      t.string :type
      t.integer :activity_id
      t.date :spent_on
      t.float :billable
      t.float :non_billable

      t.timestamps
    end
  end
end
