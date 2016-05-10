class Favorite < ActiveRecord::Base
  belongs_to :user
  belongs_to :project
  attr_accessible :project_id, :user_id
  validates_presence_of :project_id, :user_id
end