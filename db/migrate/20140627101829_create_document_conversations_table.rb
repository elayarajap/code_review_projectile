class CreateDocumentConversationsTable < ActiveRecord::Migration
  def up
  	create_table :document_conversations do |t|
      t.integer :document_id, :null => false
      t.integer :user_id, :null => false
      t.string :comment
      t.timestamp :created_on
  	end
  end

  def down
  	drop_table :document_conversations
  end
end
