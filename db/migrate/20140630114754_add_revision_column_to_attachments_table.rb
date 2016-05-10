class AddRevisionColumnToAttachmentsTable < ActiveRecord::Migration
  def change
    add_column :attachments, :revision, :string
  end
end
