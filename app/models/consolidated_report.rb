class ConsolidatedReport < ActiveRecord::Base
  include Redmine::SafeAttributes
  attr_accessible :account_id, :activity_id, :billable, :group_id, :group_name, :non_billable, :project_id, :spent_on, :activity_type, :user_id
  belongs_to :project
  belongs_to :activity
  belongs_to :user
  belongs_to :activity, :class_name => 'TimeEntryActivity', :foreign_key => 'activity_id'  

  def self.generate_scheduled_report(weeks_from=8)
    from_date=Time.now.beginning_of_week-weeks_from.week
    general_activity_id = Project.find_by_name("General Activity").id
  	time_entries = TimeEntry.where("approval_status=true and project_id!= ? and is_report_generated=false and created_on >= ?",general_activity_id,from_date).includes(:activity,:project=>:account,:user=>:groups_user)
    consolidated_report_columns = [:account_id,:group_id,:group_name,:user_id,:activity_id,:billable,:non_billable, :project_id, :spent_on, :activity_type]
    consolidated_report_values = []
    grouped_records = time_entries.group_by{|t| [t.project_id,t.user_id,t.spent_on]}
    non_ga_records = prepare_grouped_data(grouped_records,"nga")    
    
    general_activities = TimeEntry.where("approval_status=true and project_id= ? and is_report_generated=false and created_on >= ?",general_activity_id,from_date).includes(:activity,:project=>:account,:user=>:groups_user)
    grouped_ga_records = general_activities.group_by{|t| [t.activity_id,t.user_id,t.spent_on]}
    ga_records = prepare_grouped_data(grouped_ga_records,"ga")#ga - General Activity
    
    consolidated_report_values = non_ga_records + ga_records

    import consolidated_report_columns, consolidated_report_values 
    time_entries.update_all(:is_report_generated=>true)
    general_activities.update_all(:is_report_generated=>true)
  	
  end

  def self.revert_testing
    ActiveRecord::Base.connection.execute("TRUNCATE consolidated_reports")
    TimeEntry.where("approval_status=true and is_report_generated=true and created_on >= ?",(Time.now.beginning_of_day - 3.weeks)).update_all(:is_report_generated=>false)
  end

  def self.consolidated_json(start_date,end_date,group_id=nil,excel_view="false")
    start_date ||=Time.now.beginning_of_week-1.month
    end_date ||= Time.now
    # unless group_id.nil?
    #   users = GroupsUser.where(:group_id=>group_id)#Users of a particular group
    # else
    #   users = GroupsUser.pluck(:user_id).uniq#All users
    # end
    unless group_id.nil?
      reports = where("group_id = ? and spent_on between ? and ?",group_id,start_date,end_date).includes(:activity,:project=>:account,:user=>:groups_user).order("spent_on asc")
    else
      reports = where("spent_on between ? and ?",start_date,end_date).includes(:activity,:project=>:account,:user=>:groups_user).order("spent_on asc")
    end
    response_hash = Hash.new
    response_array = []
    # reports.each_with_index do |report,index|
    #   response_hash = response_hash.merge({index => {"project_id"=>report.project_id,"project_name"=>report.project.name,"user_id"=>report.user_id,"user_name"=>report.user.name,
    #     "billable"=>report.billable,"non_billable"=>report.non_billable,"activity_id"=>report.activity_id,"activity_name"=>report.activity.name,
    #     "spent_on"=>report.spent_on,"group_id"=>report.group_id,"group_name"=>report.group_name, "activity_type"=>report.activity_type, "engagement_type"=>report.project.project_type}})
    # end
    reports.find_all{|item| item.activity_type=="ga"}.group_by(&:id).each do |userid,user_data|
      response_array.push(form_json_object(user_data))
    end
    # if group_id.nil?
    if excel_view=="false" || group_id.nil?
      reports.find_all{|item| item.activity_type=="nga"}.group_by(&:user_id).each do |userid,user_data|
        response_array.push(form_json_object(user_data))
      end
    else
      reports.find_all{|item| item.activity_type=="nga"}.group_by(&:id).each do |userid,user_data|
        response_array.push(form_json_object(user_data))
      end
    end
    return response_array
  end

  def self.all_groups
    all_group_ids = GroupsUser.pluck(:group_id).uniq
    #Group.where("id in (?)",all_group_ids).to_json( :only => [:id,:lastname] )#.select("id,lastname").as_json
    {"groups" => Group.select("id,lastname AS group_name").as_json.map{|item| item["group"]} }
  end
end

public
  def form_json_object(user_data)
    report = user_data.first
    return {"project_id"=>report.project_id,"project_name"=>report.project.name,"project_type"=>report.project.project_type || "Not mentioned","user_id"=>report.user_id,"user_name"=>report.user.name,
        "billable"=>user_data.sum(&:billable),"non_billable"=>user_data.sum(&:non_billable),"activity_id"=>report.activity_id,"activity_name"=>report.activity.name,"account_name"=>report.project.account.name,
        "spent_on"=>report.spent_on.strftime("%d %b, %Y"),"group_id"=>report.group_id,"group_name"=>report.group_name, "activity_type"=>report.activity_type, "engagement_type"=>report.project.project_type}
  end

  def prepare_grouped_data(array,type)
    array_values = []
    array.each do |grouped,set|
      group_id = set.first.user.groups_user.try(:group_id)
      unless group_id.nil?
        group_name =  Rails.cache.fetch "group_name_#{group_id}" do
          Group.find_by_id(group_id).try(:lastname)
        end
      else
        group_name = "Not Assigned to any group"
      end
      billable = set.sum(&:billable)
      non_billable = set.sum(&:non_billable)
      spent_on = set.first.spent_on
      account_id = set.first.project.parent_id
      # account_name = set.first.project.account.name
      activity_id = set.first.activity_id      
      user_id = set.first.user_id
      project_id = set.first.project_id
      array_values.push [account_id,group_id,group_name,user_id,activity_id,billable,non_billable, project_id, spent_on, type]
    end
    return array_values
  end

