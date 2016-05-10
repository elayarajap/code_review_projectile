class AddTokenAndClientIdToDocuments < ActiveRecord::Migration
  def change
    add_column :documents, :token, :string
    add_column :documents, :client_id, :integer
  end
end
