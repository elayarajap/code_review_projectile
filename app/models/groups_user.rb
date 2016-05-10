class GroupsUser < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :user

end