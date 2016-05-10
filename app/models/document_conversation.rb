class DocumentConversation < ActiveRecord::Base
  belongs_to :document
  belongs_to :user
  attr_accessible :document_id, :user_id, :comment
  validates_presence_of :document_id, :user_id, :comment
end