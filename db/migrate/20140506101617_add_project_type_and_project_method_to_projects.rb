class AddProjectTypeAndProjectMethodToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :project_type, :string
    add_column :projects, :project_method, :string
  end
end
