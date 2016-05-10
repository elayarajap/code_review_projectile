class RenameStartDateColumnInVersionsTable < ActiveRecord::Migration
  def up
  	rename_column :versions, :start_date, :init_date
  end
end