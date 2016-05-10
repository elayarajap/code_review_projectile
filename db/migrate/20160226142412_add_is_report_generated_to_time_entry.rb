class AddIsReportGeneratedToTimeEntry < ActiveRecord::Migration
  def change
  	add_column :time_entries, :is_report_generated, :boolean, :default => 0
  end
end
