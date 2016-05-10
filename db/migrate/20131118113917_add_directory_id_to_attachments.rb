class AddDirectoryIdToAttachments < ActiveRecord::Migration
  def change
    add_column :attachments, :directory_id, :integer
  end
end
