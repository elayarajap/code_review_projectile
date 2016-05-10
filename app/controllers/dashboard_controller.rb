

class DashboardController < ApplicationController

  before_filter :require_login

  def show

    # Page count store from params
    page_num = params[:page].to_i
    account_per_page = 2
    page_num_position = page_num-1
    position = page_num_position*account_per_page

    user_in_group =  User.current.manager ? 1 : 0

    if User.current.admin? and user_in_group==0
      if params[:groupid].present? && params[:engagement_id].present?
        groupid_params = params[:groupid].to_i
        engagement_type = params[:engagement_id].to_i
        if engagement_type==1
          engagement_type_str = "Retainer"
        elsif engagement_type==2
          engagement_type_str = "Fixed Bid"
        else
          engagement_type_str = "T&M"
        end
        group = Group.where(:id => groupid_params).first
        project_ids = Member.where(:user_id => group.users.map(&:id)).map(&:project_id).uniq
        @all_sub_projects = Project.where(:id => project_ids,:project_type => engagement_type_str).where("parent_id IS NOT NULL").active
        @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2).offset(position)
      elsif params[:groupid].present?
        groupid_params = params[:groupid].to_i
        group = Group.where(:id => groupid_params).first
        project_ids = Member.where(:user_id => group.users.map(&:id)).map(&:project_id).uniq
        @all_sub_projects = Project.where(:id => project_ids).where("parent_id IS NOT NULL").active
        @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2).offset(position)
      elsif params[:engagement_id].present?
        engagement_type = params[:engagement_id].to_i
        if engagement_type==1
          engagement_type_str = "Retainer"
        elsif engagement_type==2
          engagement_type_str = "Fixed Bid"
        else
          engagement_type_str = "T&M"
        end
        @all_sub_projects = Project.where(:project_type => engagement_type_str).where("parent_id IS NOT NULL").active
        @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2).offset(position)
      else
        @projects = Project.where("parent_id is NULL OR parent_id=0").active.order("name ASC").limit(2).offset(position)
        @all_sub_projects = Project.where("parent_id in (?)",@projects.collect(&:id)).active
      end

    else
      @member_in_projects = Project.where("id in (select project_id from members where user_id = ?)",User.current.id).active 
      @associated_project_ids = (@member_in_projects.collect(&:parent_id) << @member_in_projects.collect(&:id)).flatten

      @projects = Project.where("id in (?) and (parent_id is NULL OR parent_id=0)",@associated_project_ids.uniq).active.order("name ASC").limit(2).offset(position)
      @all_sub_projects = Project.where("id in (?) and parent_id is NOT NULL",@member_in_projects.collect(&:id)).active
    end

    @group_client = Group.where(:lastname => "Clients").first
    @user_in_client = User.user_in_group(@group_client.id).size
    project_id_collection = @all_sub_projects.collect(&:id) << @projects.collect(&:id)
    if @user_in_client!=0
      @all_issues = Issue.where("project_id in (?) and author_id=?", project_id_collection.flatten,User.current.id).select("project_id,status_id,done_ratio,tracker_id,fixed_version_id,status_id")
    else
      @all_issues = Issue.where("project_id in (?)", project_id_collection.flatten).select("project_id,status_id,done_ratio,tracker_id,fixed_version_id,status_id")
    end
    @all_sprints = Sprint.where("project_id in (?)", project_id_collection.flatten)
    @time_entries = TimeEntry.where("project_id in (?)", project_id_collection.flatten).select("project_id,billable")
    
    respond_to do |format|
        format.html { render(:partial => 'dashboard/projects', :layout => !request.xhr?) }        
    end

  end

  def timesheet_account

    p 'Timesheet method in the controller'
    pageno = params[:pageno].to_i
    user_in_group =  User.current.manager ? 1 : 0
    account_per_page = 2
    position = pageno*account_per_page

    if User.current.admin? and user_in_group==0
      if params[:groupid].present? && params[:engagement_id].present?
         groupid_params = params[:groupid].to_i
         engagement_type = params[:engagement_id].to_i
        if engagement_type==1
          engagement_type_str = "Retainer"
        elsif engagement_type==2
          engagement_type_str = "Fixed Bid"
        else
          engagement_type_str = "T&M"
        end
        group = Group.where(:id => groupid_params).first
        project_ids = Member.where(:user_id => group.users.map(&:id)).map(&:project_id).uniq
        @all_sub_projects = Project.where(:id => project_ids,:project_type => engagement_type_str).where("parent_id IS NOT NULL").active
        @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2).offset(position)

      elsif params[:groupid].present?
        groupid_params = params[:groupid].to_i
        group = Group.where(:id => groupid_params).first
        project_ids = Member.where(:user_id => group.users.map(&:id)).map(&:project_id).uniq
        @all_sub_projects = Project.where(:id => project_ids).where("parent_id IS NOT NULL").active
        @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2).offset(position)
      elsif params[:engagement_id].present?
        engagement_type = params[:engagement_id].to_i
        if engagement_type==1
          engagement_type_str = "Retainer"
        elsif engagement_type==2
          engagement_type_str = "Fixed Bid"
        else
          engagement_type_str = "T&M"
        end
        @all_sub_projects = Project.where(:project_type => engagement_type_str).where("parent_id IS NOT NULL").active
        @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2).offset(position)
      else
        @projects = Project.where("parent_id is NULL OR parent_id=0").active.order("name ASC").limit(2).offset(position)
        @all_sub_projects = Project.where("parent_id in (?)",@projects.collect(&:id)).active
      end
    else
      @member_in_projects = Project.where("id in (select project_id from members where user_id = ?)",User.current.id).active 
      @associated_project_ids = (@member_in_projects.collect(&:parent_id) << @member_in_projects.collect(&:id)).flatten

      @projects = Project.where("id in (?) and (parent_id is NULL OR parent_id=0)",@associated_project_ids.uniq).active.order("name ASC").limit(2).offset(position)
      @all_sub_projects = Project.where("id in (?) and parent_id is NOT NULL",@member_in_projects.collect(&:id)).active
    end

    @group_client = Group.where(:lastname => "Clients").first
    @user_in_client = User.user_in_group(@group_client.id).size
    project_id_collection = @all_sub_projects.collect(&:id) << @projects.collect(&:id)
    if @user_in_client!=0
      @all_issues = Issue.where("project_id in (?) and author_id=?", project_id_collection.flatten,User.current.id).select("project_id,status_id,done_ratio,tracker_id,fixed_version_id,status_id")
    else
      @all_issues = Issue.where("project_id in (?)", project_id_collection.flatten).select("project_id,status_id,done_ratio,tracker_id,fixed_version_id,status_id")
    end
    @all_sprints = Sprint.where("project_id in (?)", project_id_collection.flatten)
    @time_entries = TimeEntry.where("project_id in (?)", project_id_collection.flatten).select("project_id,billable")
    
    respond_to do |format|
        format.html { render(:partial => 'dashboard/timesheet', :layout => !request.xhr?) }        
    end

  end

  def projects

    @project_general = @general_activity_project
    cond_general = @project_general.project_condition(Setting.display_subprojects_issues?)
    @total_hours_general = TimeEntry.visible.sum(:billable, :include => :project, :conditions => cond_general).to_f
    @tmhours = TimeEntry.where(:project_id => @project_general.id).select("hours")

    @group_client = Group.where(:lastname => "Clients").first
    @user_in_client = User.user_in_group(@group_client.id).size
    
    @time_entry ||= TimeEntry.new(:project => @project_general, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
  
    begin
      user_in_group =  User.current.manager ? 1 : 0
      @validate_user_in_group = User.current.manager ? 1 : 0

      if User.current.admin? and user_in_group==0
          @favorite_projects = Project.where("id in (select project_id from favorites where user_id = ?)",User.current.id).active 
          @all_sub_projects_favorite = Project.where("id in (?) and parent_id is NOT NULL",@favorite_projects.collect(&:id)).active

          if params[:group_id].present? && params[:engagement_id].present?
            engagement_type = params[:engagement_id].to_i
            if engagement_type==1
              engagement_type_str = "Retainer"
            elsif engagement_type==2
              engagement_type_str = "Fixed Bid"
            else
              engagement_type_str = "T&M"
            end
            projects_by_groupid_and_engagement(params[:group_id],engagement_type_str)
          elsif params[:group_id].present?
            projects_by_groupid(params[:group_id])
          elsif params[:engagement_id].present?
            engagement_type = params[:engagement_id].to_i
            if engagement_type==1
              engagement_type_str = "Retainer"
            elsif engagement_type==2
              engagement_type_str = "Fixed Bid"
            else
              engagement_type_str = "T&M"
            end
            projects_by_engagement_type(engagement_type_str)
          else
            @projects_count = Project.where("parent_id is NULL OR parent_id=0").active.count
            @projects = Project.where("parent_id is NULL OR parent_id=0").active.order("name ASC").limit(2)
            @all_sub_projects = Project.where("parent_id in (?)",@projects.collect(&:id)).active
          
            @projects_timesheet = Project.where("parent_id is NULL OR parent_id=0").active
            @all_sub_projects_timesheet = Project.where("parent_id in (?)",@projects_timesheet.collect(&:id)).active
          end

        @groups = Group.where("id in (select group_id from groups_users)")  # This code is being used for get all group to display the select box
      else
        @member_in_projects = Project.where("id in (select project_id from members where user_id = ?)",User.current.id).active 
        @member_in_closed_projects = Project.where("id in (select project_id from members where user_id = ?)",User.current.id).closed 
        @associated_project_ids = (@member_in_projects.collect(&:parent_id) << @member_in_projects.collect(&:id)).flatten
        @associated_closed_project_ids = (@member_in_closed_projects.collect(&:parent_id) << @member_in_closed_projects.collect(&:id)).flatten
        @projects_count = Project.where("id in (?) and (parent_id is NULL OR parent_id=0)",@associated_project_ids.uniq).active.count
        @projects = Project.where("id in (?) and (parent_id is NULL OR parent_id=0)",@associated_project_ids.uniq).active.order("name ASC").limit(2)

        @closed_accounts = Project.where("id in (?) and (parent_id is NULL OR parent_id=0)",@associated_closed_project_ids.uniq).closed
        @closed_projects = Project.where("id in (?) and (parent_id is NOT NULL)",@member_in_closed_projects.collect(&:id)).closed
        @all_sub_projects = Project.where("id in (?) and parent_id is NOT NULL",@member_in_projects.collect(&:id)).active 

        @favorite_projects = Project.where("id in (select project_id from favorites where user_id = ?)",User.current.id).active
        @all_sub_projects_favorite = Project.where("id in (?) and parent_id is NOT NULL",@favorite_projects.collect(&:id)).active
      
        @projects_timesheet = Project.where("id in (?) and (parent_id is NULL OR parent_id=0)",@associated_project_ids.uniq).active
        @all_sub_projects_timesheet = Project.where("id in (?) and parent_id is NOT NULL",@member_in_projects.collect(&:id)).active

      end

      account_per_page = 2
      pages_count = (@projects_count.to_f/account_per_page)
      @total_pages = pages_count.ceil

      project_id_collection = @all_sub_projects_timesheet.collect(&:id) << @projects_timesheet.collect(&:id)
      if @user_in_client!=0
        @all_issues = Issue.where("project_id in (?) and author_id=?", project_id_collection.flatten,User.current.id).select("project_id,status_id,done_ratio,tracker_id,fixed_version_id,status_id")
      else
        @all_issues = Issue.where("project_id in (?)", project_id_collection.flatten).select("project_id,status_id,done_ratio,tracker_id,fixed_version_id,status_id")
      end
      @all_sprints = Sprint.where("project_id in (?)", project_id_collection.flatten)
      @time_entries = TimeEntry.where("project_id in (?)", project_id_collection.flatten).select("project_id,billable")
    end

  end

  # This code will get the projects from selectes group associated users
  def projects_by_groupid(group_id)    
    group = Group.where(:id => group_id).first
    project_ids = Member.where(:user_id => group.users.map(&:id)).map(&:project_id).uniq
    
    @all_sub_projects = Project.where(:id => project_ids).where("parent_id IS NOT NULL").active
    @all_sub_projects_timesheet = Project.where(:id => project_ids).where("parent_id IS NOT NULL").active

    @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2)            
    @projects_timesheet = Project.where(:id => @all_sub_projects_timesheet.collect(&:parent_id))
    @projects_count = Project.where(:id => @all_sub_projects.collect(&:parent_id)).count
  end

  # This code will get the projects from selecte engagement type
  def projects_by_engagement_type(type)
    @all_sub_projects = Project.where(:project_type => type).where("parent_id IS NOT NULL").active
    @all_sub_projects_timesheet = Project.where(:project_type => type).where("parent_id IS NOT NULL").active
    
    @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2)
    @projects_timesheet = Project.where(:id => @all_sub_projects_timesheet.collect(&:parent_id))
    @projects_count = Project.where(:id => @all_sub_projects.collect(&:parent_id)).count
  end

  def projects_by_groupid_and_engagement(group_id, type)
    group = Group.where(:id => group_id).first
    project_ids = Member.where(:user_id => group.users.map(&:id)).map(&:project_id).uniq
    
    @all_sub_projects = Project.where(:id => project_ids,:project_type => type).where("parent_id IS NOT NULL").active
    @all_sub_projects_timesheet = Project.where(:id => project_ids,:project_type => type).where("parent_id IS NOT NULL").active

    @projects = Project.where(:id => @all_sub_projects.collect(&:parent_id)).order("name ASC").limit(2)            
    @projects_timesheet = Project.where(:id => @all_sub_projects_timesheet.collect(&:parent_id))
    @projects_count = Project.where(:id => @all_sub_projects.collect(&:parent_id)).count
  end

  def get_projects
    @projects = Project.where("parent_id is NULL").active
    @issues = Issue.recently_updated.limit(5)
    render :layout => false
  end

  def view_all_projects
    @projects = Project.where(:id =>params[:id]).active
    @issues = Issue.recently_updated.limit(5)
  end

  def view_project_details
    @projects = Project.where(:id =>params[:id])
    @project = @projects.first
    @all_sub_projects = Project.where("parent_id = ?",@project.id).active
    project_id_collection = @all_sub_projects.collect(&:id) << @projects.collect(&:id)
    @all_isses = Issue.where("project_id in (?)", project_id_collection.flatten)
    @all_sprints = Sprint.where("project_id in (?)", project_id_collection.flatten)
    @time_entries = TimeEntry.where("project_id in (?)", project_id_collection.flatten)
    @group_client = Group.where(:lastname => "Clients").first
    @user_in_client = User.user_in_group(@group_client.id).size
    if @user_in_client!=0
      @all_issues = Issue.where("fixed_version_id in (?) and author_id=?",@all_sprints.collect(&:id),User.current.id)
    else
      @all_issues = Issue.where("fixed_version_id in (?)",@all_sprints.collect(&:id))        
    end
  end

end
