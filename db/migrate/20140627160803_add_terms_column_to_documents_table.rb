class AddTermsColumnToDocumentsTable < ActiveRecord::Migration
  def change
  	add_column :documents, :terms, :integer
  end
end
