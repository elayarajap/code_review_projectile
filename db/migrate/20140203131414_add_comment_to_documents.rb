class AddCommentToDocuments < ActiveRecord::Migration
  def change
    add_column :documents, :comment, :text
  end
end
