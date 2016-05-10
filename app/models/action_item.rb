class ActionItem < ActiveRecord::Base
  belongs_to :meeting
  attr_accessible :item, :user_id, :meeting_id, :fixed_version_id, :date
  before_create :test_new_record
  after_create :create_corresponding_issue
  before_update :find_old_record_and_update_issue
  before_destroy :find_old_record_and_destroy_issue
  


 def test_new_record
	@new_action_item = new_record?
	return true
 end

 def create_corresponding_issue

  	if @new_action_item
  		@new_object = self
  		@issue = Issue.new(:subject => @new_object.item, :fixed_version_id => @new_object.fixed_version_id, :priority_id => 2, :tracker_id => 2, :author_id => User.current.id, :assigned_to_id => @new_object.user_id, :project_id => @new_object.meeting.project_id)
      @issue.save
      
    end
 end

def find_old_record_and_update_issue
  unless new_record?
    old_item = ActionItem.find(self.id)
    @issue = Issue.find_by_subject(old_item.item) 
    if @issue
    @issue.subject = self.item
    @issue.save
    end
  end
end

def find_old_record_and_destroy_issue
  old_item = ActionItem.find(self.id)
  @issue = Issue.find_by_subject(old_item.item)
  @issue.delete if @issue
end

end
