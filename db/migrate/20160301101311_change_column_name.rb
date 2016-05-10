class ChangeColumnName < ActiveRecord::Migration
  def up
  	rename_column :consolidated_reports, :type, :activity_type
  end

  def down
  	rename_column :consolidated_reports, :activity_type, :type
  end
end
