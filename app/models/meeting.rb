class Meeting < ActiveRecord::Base
  belongs_to :project
  #belongs_to :meeting_type
  attr_accessible :project_id, :title, :discussion_summary, :date, :time, :end_date, :end_time, :attendees, :fixed_version_id, :action_items_attributes, :custom_attendees_attributes
  has_many :action_items, :dependent => :destroy
  has_many :custom_attendees, :dependent => :destroy
  accepts_nested_attributes_for :action_items, :reject_if => lambda { |a| a[:item].blank? }, :allow_destroy => true                          
  accepts_nested_attributes_for :custom_attendees, :reject_if => lambda { |a| a[:name].blank? }, :allow_destroy => true                               
  validates_presence_of :title, :discussion_summary, :date, :time, :end_date, :end_time
  attr_accessor :custom_emails
  validates_format_of :custom_emails, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i , :allow_blank => true
end