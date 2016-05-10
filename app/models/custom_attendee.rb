class CustomAttendee < ActiveRecord::Base
  attr_accessible :email, :meeting_id, :name
  belongs_to :meeting

  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i , :allow_blank => true
end
