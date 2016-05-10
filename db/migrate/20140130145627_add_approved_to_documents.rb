class AddApprovedToDocuments < ActiveRecord::Migration
  def change
    add_column :documents, :approved, :boolean, :default => 0
  end
end
