class AddGroupmailColumnInProjectsTable < ActiveRecord::Migration
  def up
  	add_column :projects, :group_mail_address, :string
  end

  def down
  	remove_column :projects, :group_mail_address
  end
end
