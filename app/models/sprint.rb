class Sprint < ActiveRecord::Base
  self.table_name = "versions"
  belongs_to :project
  attr_accessible :project_id, :name
end