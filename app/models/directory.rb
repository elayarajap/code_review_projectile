class Directory < ActiveRecord::Base
  self.table_name = "directories"
  belongs_to :project
  validates_presence_of :name
  attr_accessible :project_id, :name
end