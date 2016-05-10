# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class ProjectsController < ApplicationController
  menu_item :overview
  menu_item :roadmap, :only => :roadmap
  menu_item :settings, :only => :settings
  before_filter :require_login
  before_filter :find_project, :except => [ :index, :list, :new, :create, :copy, :add_to_favorite, :remove_favorite]
  before_filter :authorize, :except => [ :index, :list, :new, :create, :copy, :archive, :unarchive, :destroy, :initiation_mail, :add_to_favorite, :remove_favorite]
  before_filter :authorize_global, :only => [:new, :create]
  before_filter :require_admin, :only => [ :copy, :archive, :unarchive, :destroy ]
  accept_rss_auth :index
  accept_api_auth :index, :show, :create, :update, :destroy

  after_filter :only => [:create, :edit, :update, :archive, :unarchive, :destroy] do |controller|
    if controller.request.post?
      controller.send :expire_action, :controller => 'welcome', :action => 'robots'
    end
  end

  helper :sort
  include SortHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issues
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  include ProjectsHelper
  helper :members

  # Lists visible projects
  def index
    respond_to do |format|
      format.html {
        scope = Project
        unless params[:closed]
          scope = scope.active
        end
        @projects = scope.visible.order('lft').all
      }
      format.api  {
        @offset, @limit = api_offset_and_limit
        @project_count = Project.visible.count
        @projects = Project.visible.offset(@offset).limit(@limit).order('lft').all
      }
      format.atom {
        projects = Project.visible.order('created_on DESC').limit(Setting.feeds_limit.to_i).all
        render_feed(projects, :title => "#{Setting.app_title}: #{l(:label_project_latest)}")
      }
    end
  end

  def new
    @issue_custom_fields = IssueCustomField.sorted.all
    @trackers = Tracker.sorted.all
    @project = Project.new
    @project.safe_attributes = params[:project]
  end

  def create
    @issue_custom_fields = IssueCustomField.sorted.all
    @trackers = Tracker.sorted.all
    @project = Project.new
    @project.safe_attributes = params[:project]

    if validate_parent_id && @project.save

      directory = Directory.new(:project_id => @project.id, :name => "others")
      directory.save
      version = Version.new(:project_id => @project.id, :name => "default", :description=>"", :status=>"open", :wiki_page_title=>"", :init_date=>"", :effective_date=>"", :sharing=>"none")
      version.save
      @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
      # Add current user as a project member if he is not admin

      # Managers group for automatic member assigning
      if check_usr_in_group || !User.current.admin?
        r = Role.givable.find_by_id(Setting.new_project_user_role_id.to_i) || Role.givable.first
        m = Member.new(:user => User.current, :roles => [r])
        @project.members << m
      end

      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_create)
          if params[:continue]
            attrs = {:parent_id => @project.parent_id}.reject {|k,v| v.nil?}
            redirect_to new_project_path(attrs)
          else
            redirect_to settings_project_path(@project)
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => url_for(:controller => 'projects', :action => 'show', :id => @project.id) }
      end
    else
      respond_to do |format|

        if !params[:project].has_key?("parent_id")
          format.html { render :action => 'new' }
        else
          @custom_project_id = params[:project][:parent_id]
          @custom_project_name = params[:project][:parent_name]
          format.html { render :action => 'new' }
        end
        format.api  { render_validation_errors(@project) }

      end
    end
  end

  def copy
    @issue_custom_fields = IssueCustomField.sorted.all
    @trackers = Tracker.sorted.all
    @source_project = Project.find(params[:id])
    if request.get?
      @project = Project.copy_from(@source_project)
      @project.identifier = Project.next_identifier if Setting.sequential_project_identifiers?
    else
      Mailer.with_deliveries(params[:notifications] == '1') do
        @project = Project.new
        @project.safe_attributes = params[:project]
        if validate_parent_id && @project.copy(@source_project, :only => params[:only])
          @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
          flash[:notice] = l(:notice_successful_create)
          redirect_to settings_project_path(@project)
        elsif !@project.new_record?
          # Project was created
          # But some objects were not copied due to validation failures
          # (eg. issues from disabled trackers)
          # TODO: inform about that
          redirect_to settings_project_path(@project)
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    # source_project not found
    render_404
  end

  # Show @project
  def show
    cond = @project.project_condition(Setting.display_subprojects_issues?)
    if User.current.allowed_to?(:view_time_entries, @project)
     @total_hours = TimeEntry.where("project_id = ?", @project.id)
    end

    @group_client = Group.where(:lastname => "Clients").first
    @user_in_client = User.user_in_group(@group_client.id).size

    @sprints = Version.where(:project_id => @project.id)
    @is_any_sprint_open = @sprints.collect(&:status).include?('open')
    if @user_in_client!=0
      @all_issues = Issue.where("fixed_version_id in (?) and author_id=?",@sprints.collect(&:id),User.current.id)
    else
      @all_issues = Issue.where("fixed_version_id in (?)",@sprints.collect(&:id))        
    end

    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
  end

  def settings
    if request.xhr?
      @user = User.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option)
      user_created = @user.update_attributes(:mail=>params[:client_email],:login=>params[:client_email].split("@").first,:firstname=>params[:first_name],:lastname=>params[:last_name],:password=>"password",:password_confirmation=>"password")
      @user.password = "password"
      @user.password_confirmation = "password"
      user_created = @user.save
      if user_created
        Thread.new { Mailer.account_information(@user, "password").deliver if @user.present? }
        @project = Project.find_by_id(params[:id])
        member = Member.new(:role_ids => [Role.find_by_name("Client").id], :user_id => @user.id)
        @project.members << member
        @group_client = Group.where(:lastname => "Clients",:type=>"Group").first
        ActiveRecord::Base.connection.execute("insert into groups_users (group_id,user_id) values (#{@group_client.id},#{@user.id});")
      else
        respond_to do |format|
          format.json  {render :json => {:failure => true}}
        end
      end
    end

    @sprints = Version.where(:project_id => @project.id)
    @is_any_sprint_open = @sprints.collect(&:status).include?('open')

    cond = @project.project_condition(Setting.display_subprojects_issues?)
    if User.current.allowed_to?(:view_time_entries, @project)
     @total_hours = TimeEntry.where("project_id = ?", @project.id)
    end  
    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]    
    @issue_custom_fields = IssueCustomField.sorted.all
    @issue_category ||= IssueCategory.new
    @member ||= @project.members.new
    @trackers = Tracker.sorted.all
    @wiki ||= @project.wiki
  end

  def edit
  end

  def update
    @project.safe_attributes = params[:project]
    if validate_parent_id && @project.save
      @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
      if request.xhr?
        initiation
          render :update do |page|
            page.replace_html  "initiation_mail_templet", :partial => "/project/preview", :locals => {:initiation_details => @initiation_details }
          end
      else
        respond_to do |format|
          format.html {
            flash[:notice] = l(:notice_successful_update)
            redirect_to settings_project_path(@project)
          }
          format.api  { render_api_ok }
        end
      end
    else
      respond_to do |format|
        format.html {
          settings
          render :action => "settings"
        }
        format.api  { render_validation_errors(@project) }
      end
    end
  end

  def modules
    @project.enabled_module_names = params[:enabled_module_names]
    flash[:notice] = l(:notice_successful_update)
    redirect_to settings_project_path(@project, :tab => 'modules')
  end

  def archive
    if request.post?
      unless @project.archive
        flash[:error] = l(:error_can_not_archive_project)
      end
    end
    redirect_to admin_projects_path(:status => params[:status])
  end

  def unarchive
    @project.unarchive if request.post? && !@project.active?
    redirect_to admin_projects_path(:status => params[:status])
  end

  def close
    @project.close
    #redirect_to project_path(@project)
    redirect_to project_time_entries_path(@project)
  end

  def reopen
    parent_id = @project.parent_id
    if(!parent_id.nil? && parent_id != 0)
      @account = Project.find(parent_id)
      @account.reopen if @account.status == 5
    end
    @project.reopen
    #redirect_to project_path(@project)
    redirect_to project_time_entries_path(@project)
  end

  # Delete @project
  def destroy
    @project_to_destroy = @project
    if api_request? || params[:confirm]
      @project_to_destroy.destroy
      respond_to do |format|
        format.html { redirect_to admin_projects_path }
        format.api  { render_api_ok }
      end
    end
    # hide project in layout
    @project = nil
  end

  def initiation
    #custom_details
    @project_client_flag = 0
    @members = @project.members
    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @project_client_flag = 1
      end
    end


    project_custom_fields = CustomField.where(:type=>"ProjectCustomField").select([:id,:type,:name])
    project_custom_values = CustomValue.where(:customized_id=>@project.id).select([:custom_field_id,:value])
    initiation_details=[]
    @initiation_details=[]

    project_custom_fields.each do |custom_field|
    custom_value = project_custom_values.find_all{|custom_value| custom_value.custom_field_id==custom_field.id}.first.try(:value)
     initiation_details << {:custom_field_name => custom_field.name, :custom_field_value => custom_value}
    end

  fetch_project_users

  # @project_type = initiation_details.find_all{|item| item[:custom_field_name]=="Project Type"}.first[:custom_field_value]
  # @initiation_details << @project_type
  #@client_name = initiation_details.find_all{|item| item[:custom_field_name]=="Client Name"}.first[:custom_field_value]
  @initiation_details << "dummy"
  @source_control = initiation_details.find_all{|item| item[:custom_field_name]=="Source control"}.first[:custom_field_value]
  @initiation_details << @source_control
  @html_layout = initiation_details.find_all{|item| item[:custom_field_name]=="HTML Layouts"}.first[:custom_field_value]
  @initiation_details << @html_layout
  @project_start_date = initiation_details.find_all{|item| item[:custom_field_name]=="Project Start Date"}.first[:custom_field_value]
  @initiation_details << @project_start_date
  @apis_required = initiation_details.find_all{|item| item[:custom_field_name]=="APIs required"}.first[:custom_field_value]
  @initiation_details << @apis_required
  @staging_environment = initiation_details.find_all{|item| item[:custom_field_name]=="Staging environment"}.first[:custom_field_value]
  @initiation_details << @staging_environment
  @client_company_name = initiation_details.find_all{|item| item[:custom_field_name]=="Client company name"}.first[:custom_field_value]
  @initiation_details << @client_company_name
  @uat_environment = initiation_details.find_all{|item| item[:custom_field_name]=="UAT environment"}.first[:custom_field_value]
  @initiation_details << @uat_environment
  @sow_date = initiation_details.find_all{|item| item[:custom_field_name]=="SoW Date"}.first[:custom_field_value]
  @initiation_details << @sow_date
  @location = initiation_details.find_all{|item| item[:custom_field_name]=="Location"}.first[:custom_field_value]
  @initiation_details << @location
  @application_database = initiation_details.find_all{|item| item[:custom_field_name]=="Application Database"}.first[:custom_field_value]
  @initiation_details << @application_database
  @systems_to_be_integrated_with = initiation_details.find_all{|item| item[:custom_field_name]=="Systems to be integrated with"}.first[:custom_field_value]
  @initiation_details << @systems_to_be_integrated_with
  @effort_months = initiation_details.find_all{|item| item[:custom_field_name]=="Effort /Schedule Months"}.first[:custom_field_value]
  @initiation_details << @effort_months  
  @effort_hours = initiation_details.find_all{|item| item[:custom_field_name]=="Effort /Schedule Hours"}.first[:custom_field_value]
  @initiation_details << @effort_hours   
   user_custom_fields_hash
  end

  def initiation_mail
    @client = Array.new
    @email_ids = Array.new
    @members = @project.members
    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @client << mem.user_id
      end
    end 
    group_mail = @project.group_mail_address
    if @client.present? && !group_mail.nil?
     @client.each do |id|
        client = User.find(id) 
        @email_ids << {:email => client.mail, :name => client.firstname}        
      end
      @email_ids << {:email => group_mail, :name => group_mail.split("@")[0]}
      initiation
      Thread.new { Mailer.project_initiation_mail(@email_ids, @initiation_details, @project, @project_devs, @project_manager,@contact_number,@designation,@skype_id,@experience,@hash,@project_clients).deliver }
      flash[:notice] = "Initiation mail successfully sent."
      cus_field_val = is_mail_sent.present? ? is_mail_sent.update_attributes(:value=>true) : nil      
      redirect_to initiation_project_path(@project)      
    else
      flash[:error] = "Client email address and project group email address are mandatory! Please check project settings and enable it"
      redirect_to initiation_project_path(@project)
    end
  end

  def add_to_favorite
    @project_fav = Favorite.new()
    @project_fav.user_id = User.current.id
    @project_fav.project_id = params[:id]

    @pro_fav_exists = Favorite.where("project_id = ? AND user_id = ?", params[:id], User.current.id).first
    
    if @pro_fav_exists.nil?
      if @project_fav.save
        flash[:notice] = "Project has been added to your favorites"
        redirect_to(:back)
      else
        flash[:error] = "Unable to add the project to your favorites"
        redirect_to(:back)
      end
    else
      flash[:error] = "Project is already your favorite!"
      redirect_to(:back)
    end
  end

  def remove_favorite
    @remove_fav = Favorite.where("project_id = ? AND user_id = ?", params[:id], User.current.id).first
   
    if @remove_fav.destroy
      flash[:notice] = "Project has been removed from your favorites"
      redirect_to(:back)
    else
      flash[:error] = "Unable to remove the project from your favorites"
      redirect_to(:back)
    end 
  end

  def fetch_project_users
    project_devs = []
    project_manager = []
    project_clients = []
    @project.members.each do |member|
      member.member_roles.each do |member_role|
        if member_role.role.try(:name) == "Manager"
          project_manager << member.user
        end
        if member_role.role.try(:name) == "Developer" && member_role.role.try(:name) != "Manager"
          project_devs << member.user
        end
        if member_role.role.try(:name) == "Client"
          project_clients << member.user.firstname.capitalize
        end
      end      
    end    
    @project_devs = (project_devs - project_manager)
    @project_manager = project_manager.first
    @project_clients = project_clients
  end

  def user_custom_fields_hash
    users_custom_fields = CustomField.where(:type=>"UserCustomField").select([:id,:name])    
    user_ids=[]
    @contact_number = []
    @designation = []
    @skype_id = []
    @experience = []
    @all_dev_cust_values = CustomValue.where("customized_id in (?) and customized_type=?",(@project_devs.collect(&:id) << @project_manager.id),"principal")
    @project.members.each_with_index do |member,counter|
      developer = member.user
      user_ids << developer.id
      users_custom_values = @all_dev_cust_values.find_all{|item| item.customized_id==developer.id}
      users_custom_fields.each do |user_custom_field|        
        custom_value = users_custom_values.find_all{|custom_value| custom_value.custom_field_id==user_custom_field.id}.first.try(:value)
        
        if user_custom_field.name=="Skype ID" 
          @skype_id[counter] = custom_value
        end
        if user_custom_field.name=="Contact Number" 
          @contact_number[counter] = custom_value
        end
        if user_custom_field.name=="Designation" 
          @designation[counter] = custom_value
        end
        if user_custom_field.name=="Experience" 
          @experience[counter] = custom_value
        end
      end            
    end

    @hash = Hash[user_ids.map.with_index.to_a]
    
  end


  private

  # Validates parent_id param according to user's permissions
  # TODO: move it to Project model in a validation that depends on User.current
  def validate_parent_id
    return true if User.current.admin?
    return true if User.current.manager?
    parent_id = params[:project] && params[:project][:parent_id]
    if parent_id || @project.new_record?
      parent = parent_id.blank? ? nil : Project.find_by_id(parent_id.to_i)
      unless @project.allowed_parents.include?(parent)
        @project.errors.add :parent_id, :invalid
        return false
      end
    end
    true
  end
end
