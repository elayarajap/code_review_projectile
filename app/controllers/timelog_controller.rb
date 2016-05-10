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

class TimelogController < ApplicationController
  menu_item :issues
  before_filter :require_login
  before_filter :find_project_for_new_time_entry, :only => [:create]
  before_filter :find_time_entry, :only => [:show, :edit, :update]
  before_filter :find_time_entries, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :authorize, :except => [:new, :index, :report, :unapproved, :update_approval_status]

  before_filter :find_optional_project, :only => [:index, :report, :unapproved]
  before_filter :find_optional_project_for_new_time_entry, :only => [:new]
  before_filter :authorize_global, :only => [:new, :index, :report, :update_approval_status]
  before_filter :managerial_access, :only => [:index, :report, :unapproved]


  accept_rss_auth :index
  accept_api_auth :index, :show, :create, :update, :destroy

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :sort
  include SortHelper
  helper :issues
  include TimelogHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :queries
  include QueriesHelper

  def managerial_access
    #@group_manager = Group.where(:lastname => "Managers").first
    #@user_in_group = User.user_in_group(@group_manager.id).size
    @user_in_group =  User.current.manager ? 1 : 0
    manager_role_id= Role.find_by_name('Manager').id
    @manager_roles = MemberRole.where('role_id=?',manager_role_id)
    @admin_or_manager = User.current.admin? || @user_in_group!=0
    unless @project.nil?
      @project_manager = Member.where('user_id=? and project_id=? and id in (?)',User.current.id,@project.id,@manager_roles.collect(&:member_id))    
      @admin_or_manager = User.current.admin? || @user_in_group!=0
    end    
  end

  def index 
    if params.has_key?(:format) && params[:format].include?("csv") && params.has_key?(:v)
      if params[:v].include?("user_id")
        params[:v][:user_id] = params[:v][:user_id].first.split(' ')
      end
      if params[:v].include?("activity_id")
        params[:v][:activity_id] = params[:v][:activity_id].first.split(' ')
      end
      if params[:v].include?("project_id")
        params[:v][:project_id] = params[:v][:project_id].first.split(' ')
      end
      if params[:v].include?("spent_on")
        params[:v][:spent_on] = params[:v][:spent_on].first.split(' ')
      end
    end

    if params.has_key?(:f) && params[:f].include?("group_id") && params.has_key?(:v) && params[:v].include?("user_id")
    params[:f].delete "group_id"
    end


    @query = TimeEntryQuery.build_from_params(params, :project => @project, :name => '_')   
    scope = time_entry_scope

    sort_init(@query.sort_criteria.empty? ? [['spent_on', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)

    unless @project.nil?
      @sprints = Version.where(:project_id => @project.id)
      @is_any_sprint_open = @sprints.collect(&:status).include?('open')
    else
      @is_any_sprint_open = true;
    end

    #@group_manager_chk = Group.where(:lastname => "Managers").first
    #@user_in_group_chk = User.user_in_group(@group_manager_chk.id).size
    @user_in_group_chk =  User.current.manager ? 1 : 0
    @groups_available = []
    @all_groups = Group.where("lastname != 'Clients'")
    for all_group in @all_groups
      total_user_in_group = User.in_group(all_group.id).size
      user_in_group = User.user_in_group(all_group.id).size
      if @user_in_group_chk!=0 && user_in_group!=0 && total_user_in_group>0 && User.current.admin?
        @groups_available << all_group
      elsif @user_in_group_chk==0 && total_user_in_group>0 && User.current.admin?
        @groups_available << all_group
      end
    end
    
    respond_to do |format|
      format.html {
        # Paginate results
        @entry_count = scope.count
        @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause,
          :limit  =>  @entry_pages.per_page,
          :offset =>  @entry_pages.offset
        )

        #@total_hours = scope.sum(:hours).to_f
        #@total_billable_hours = scope.sum(:billable).to_f

        #@total_hours = TimeEntry.sum_hours(scope.collect(&:hours))
        @total_hours = TimeEntry.sum_hours(scope.collect{ |x| x.hours unless x.approval_status == false})
        @total_billable_hours = TimeEntry.sum_hours(scope.collect(&:billable))
        @total_approved_hours = TimeEntry.sum_hours(scope.find_all{|item| item.approval_status==true}.collect(&:hours))
        @total_rejected_hours = TimeEntry.sum_hours(scope.find_all{|item| item.approval_status==false}.collect(&:hours))
        #@entries = @entries.find_all{|item| item.approval_status==false}

        @entries = filter_user_based(@entries)

        render :layout => !request.xhr?
      }
      format.api  {
        @entry_count = scope.count
        @offset, @limit = api_offset_and_limit
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause,
          :limit  => @limit,
          :offset => @offset
        )
        
      }
      format.atom {
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => "#{TimeEntry.table_name}.created_on DESC",
          :limit => Setting.feeds_limit.to_i
        )
        entries = filter_user_based(@entries)
        
        render_feed(entries, :title => l(:label_spent_time))
      }
      format.csv {
        # Export all entries
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => [:tracker, :assigned_to, :priority]}],
          :order => sort_clause
        )
        @entries = filter_user_based(@entries)
        send_data(query_to_csv_timelog(@entries, @query, params), :type => 'text/csv; header=present', :filename => 'timelog.csv')
      }
    end
  end

  def report
    
    @query = TimeEntryQuery.build_from_params(params, :project => @project, :name => '_')

    scope = time_entry_scope

    unless @project.nil?
      @sprints = Version.where(:project_id => @project.id)
      @is_any_sprint_open = @sprints.collect(&:status).include?('open')
    else
      @is_any_sprint_open = true;
    end

    #@thours = TimeEntry.sum_hours(scope.collect(&:hours))
    @thours = TimeEntry.sum_hours(scope.collect{ |x| x.hours unless x.approval_status == false})
    #scope = scope.find_all{|item| item.approval_status==true} This filter is made in lib/redmine/helpers/time_report.rb LINE:48

    @report = Redmine::Helpers::TimeReport.new(@project, @issue, params[:criteria], params[:columns], scope, params[:hours_type])

    @total_hours_gn_report = TimeEntry.sum_hours(scope.collect(&:hours))

    @total_billable_hours = TimeEntry.sum_hours(scope.collect(&:billable))

    @scope = scope.where(:approval_status=>true)

    @total_approved_hours = TimeEntry.sum_hours(scope.find_all{|item| item.approval_status==true}.collect(&:hours))
    #@total_approved_hours = TimeEntry.sum_hours(@scope.map{|hash| hash['hours'].to_f.round(2)})

    #@th_rp_sub = TimeEntry.sum_hours(scope.collect(&:non_billable))

    @th_rp_sub = TimeEntry.subtract_hours(@total_approved_hours,@total_billable_hours)


    #@total_hours_test = TimeEntry.sum_hours(@scope.collect(&:hours))

    #@total_hours_test = @scope.sum(:hours)


    @groups_available = []
        @all_groups = Group.sorted.all
        for all_group in @all_groups
          user_in_group = User.user_in_group(all_group.id).size
          if user_in_group!=0 || User.current.admin?
            @groups_available << all_group
          end
        end

    respond_to do |format|
      format.html { render :layout => !request.xhr? }
      format.csv  { send_data(report_to_csv(@report), :type => 'text/csv; header=present', :filename => 'timelog.csv') }
    end
  end

  def filter_user_based(filterable_entries)    
    #If not admin or manager, user should see only his own entries of techaffinity account
    if !@admin_or_manager
      filterable_entries = filterable_entries.find_all{|entry| entry.user_id==User.current.id or entry.project_id!=@general_activity_project.id}
      techaffinity_account = Project.where(:identifier=>"techaffinity").first
      unless techaffinity_account.nil?
        techaffinity_projects = Project.where(:parent_id => techaffinity_account.id)
        filterable_entries = filterable_entries.find_all{|entry| (techaffinity_projects.collect(&:id).exclude? entry.project_id) or entry.user_id==User.current.id}
      end
      return filterable_entries
    elsif @user_in_group.size>0 && @project && @project.id==@general_activity_project.id #&& !(params.include?(:op) && params[:op].include?("user_id"))      
      @all_groups = Group.all
      users_values = []
      for all_group in @all_groups
        total_user_in_group = User.in_group(all_group.id)
        user_in_group = User.user_in_group(all_group.id).size
        if user_in_group!=0 && total_user_in_group.size>0
          users_values << total_user_in_group.collect(&:id)
        end
      end
      if users_values.size>0
        filterable_entries.find_all{|entry| users_values.flatten.include? entry.user_id}      
      else
        filterable_entries    
      end
    else
      filterable_entries    
    end    
  end

  def unapproved

    if request.xhr?
     @query = TimeEntryQuery.build_from_params(params[:filter_params], :project => @project, :name => '_')
     @filter_params = params[:filter_params]
    else
    @query = TimeEntryQuery.build_from_params(params, :project => @project, :name => '_')
    @filter_params = params
    end
    scope = time_entry_scope

    unless @project.nil?
      @sprints = Version.where(:project_id => @project.id)
      @is_any_sprint_open = @sprints.collect(&:status).include?('open')
    else
      @is_any_sprint_open = true;
    end

    #@group_manager_chk = Group.where(:lastname => "Managers").first
    #@user_in_group_chk = User.user_in_group(@group_manager_chk.id).size
    @user_in_group_chk =  User.current.manager ? 1 : 0
    @groups_available = []
    @all_groups = Group.sorted.all
    for all_group in @all_groups
      total_user_in_group = User.in_group(all_group.id).size
      user_in_group = User.user_in_group(all_group.id).size
      if @user_in_group_chk!=0 && user_in_group!=0 && total_user_in_group>0 && User.current.admin?
        @groups_available << all_group
      elsif @user_in_group_chk==0 && total_user_in_group>0 && User.current.admin?
        @groups_available << all_group
      end
    end

    sort_init(@query.sort_criteria.empty? ? [['spent_on', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)

    @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause
        )
        @entries = filter_user_based(@entries)
        @@entries_for_status = @entries

  if !request.xhr?
    respond_to do |format|
      format.html {
        # Paginate results
        #@entry_count = scope.count
        #@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
        @entries 
        #@total_hours = scope.sum(:hours).to_f
        @total_hours_gn = TimeEntry.sum_hours(@entries.find_all{|entry| entry.approval_status==nil}.collect(&:hours))
        #@unapproved_hours = TimeEntry.sum_hours(@entries)
        render :layout => !request.xhr?
      }
      format.api  {
        @entries = scope.all(
          :include => [:project, :activity, :user, {:issue => :tracker}],
          :order => sort_clause
        )
      }
    end
    end
  end


  def update_approval_status    
    ActiveRecord::Base.transaction do            
     
      log_status=params[:log_status]
      issue_id=params[:issue_id].to_s
      if params.has_key?(:multiple_entries)
        params["multiple_entries"].each do |params|           
          TimeEntry.update_approval_details(params[1],issue_id,log_status)
        end
      else
        TimeEntry.update_approval_details(params,issue_id,log_status)
      end
      end
      
      if !params[:filter_params][:issue_id].blank?
        @issue = Issue.find(params[:filter_params][:issue_id])
        @project = @issue.project
      elsif !params[:filter_params][:project_id].blank?
        @project = Project.find(params[:filter_params][:project_id])
      elsif !params[:filter_params][:id].blank?
        @project = Project.find(params[:filter_params][:id])
      end
      managerial_access
      unapproved
    unless @@entries_for_status.empty?
     respond_to do |format|
        format.html { render :partial => 'unapproved_logs', :locals => { :entries => @@entries_for_status } }
     end
     end 
    

  #     if log_status=="approve"
  #       if issue_id!="0" and issue_id!="ga"#ga is for general activity
  #         TimeEntry.update_issues_billable_details(issue_id)          
  #       end
  #       render :text => "Approved successfully"
  #     else
  #       render :text => "Rejected successfully"
  #     end
  #  end
  # rescue => error
  #   p "Error has occured: #{error}"
  #   render :text => "Some error has occured, please try again later."    
   end


  def show
    respond_to do |format|
      # TODO: Implement html response
      format.html { render :nothing => true, :status => 406 }
      format.api
    end
  end

  def new
   if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.where("project_id = ?", @project.id)
   end
    @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today, :billable => 0, :non_billable => 0)
    @time_entry.safe_attributes = params[:time_entry]
    render :layout => false if params[:new_log]
  end

  def create
    if params[:mins]!='0'
      params[:mins] = (params[:mins]!='5' ? params[:mins] : ('0' << params[:mins]))
      params[:time_entry][:hours] = params[:time_entry][:hours] << '.' << params[:mins]
    end

    if params[:time_entry].has_key?(:user)
        user = User.find(params[:time_entry][:user])
        @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => user, :spent_on => User.current.today, :hours_type=>params[:hours_type])
    else
        @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today, :hours_type=>params[:hours_type])  
    end
      
    @time_entry.safe_attributes = params[:time_entry]

    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

    if @time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_create)
          if params[:continue]
            if params[:project_id]
              options = {
                :time_entry => {:issue_id => @time_entry.issue_id, :activity_id => @time_entry.activity_id},
                :back_url => params[:back_url]
              }
              if @time_entry.issue
                redirect_to new_project_issue_time_entry_path(@time_entry.project, @time_entry.issue, options)
              else
                redirect_to new_project_time_entry_path(@time_entry.project, options)
              end
            else
              options = {
                :time_entry => {:project_id => @time_entry.project_id, :issue_id => @time_entry.issue_id, :activity_id => @time_entry.activity_id},
                :back_url => params[:back_url]
              }
              redirect_to new_time_entry_path(options)
            end
          else
            respond_to do |format|
              format.html { 
              if request.xhr? 
                render :action => 'new', :locals => {:total_hours => @total_hours = TimeEntry.where("project_id = ?", @project.id)}   
              else                
                redirect_to new_issue_time_entry_path(@time_entry.issue)
              end
              #flash[:error] = "Valid Issue, Comments, Time and Activity are mandatory for Time Logging!"
               }              
            end
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => time_entry_url(@time_entry) }
      end
    else
      if params[:time_entry][:form_type] && params[:time_entry][:form_type] == "partial_form"
      respond_to do |format|
        format.html { 
        render :text => 'Failed!'
         }
        format.api  { render_validation_errors(@time_entry) }
      end
     else
       respond_to do |format|
        format.html { 
        render :action => 'new', :locals => {:total_hours => @total_hours = TimeEntry.where("project_id = ?", @project.id)}
        #flash[:error] = "Valid Issue, Comments, Time and Activity are mandatory for Time Logging!"
         }
        format.api  { render_validation_errors(@time_entry) }
      end
     end
    end
  end

  def edit
    @time_entry.safe_attributes = params[:time_entry]
  end

  def update
    if params[:mins]!='0'
      params[:time_entry][:hours] = params[:time_entry][:hours] << '.' << params[:mins]
    end



    if params[:time_entry].has_key?(:user)
        user = User.find(params[:time_entry][:user])
        @time_entry.user_id = params[:time_entry][:user]
    else
        @time_entry.user_id = User.current.id
    end

    @time_entry.safe_attributes = params[:time_entry]

    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

    if @time_entry.save    
      if params[:time_entry].has_key?(:billable)        
        TimeEntry.update_issues_billable_details(@time_entry.issue_id)          
      end      
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_update)
          redirect_back_or_default project_time_entries_path(@time_entry.project)
        }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@time_entry) }
      end
    end
  end

  def bulk_edit
    @available_activities = TimeEntryActivity.shared.active
    @custom_fields = TimeEntry.first.available_custom_fields
  end

  def bulk_update
    attributes = parse_params_for_bulk_time_entry_attributes(params)

    unsaved_time_entry_ids = []
    @time_entries.each do |time_entry|
      time_entry.reload
      time_entry.safe_attributes = attributes
      call_hook(:controller_time_entries_bulk_edit_before_save, { :params => params, :time_entry => time_entry })
      unless time_entry.save
        logger.info "time entry could not be updated: #{time_entry.errors.full_messages}" if logger && logger.info
        # Keep unsaved time_entry ids to display them in flash error
        unsaved_time_entry_ids << time_entry.id
      end
    end
    set_flash_from_bulk_time_entry_save(@time_entries, unsaved_time_entry_ids)
    redirect_back_or_default project_time_entries_path(@projects.first)
  end

  def destroy
    destroyed = TimeEntry.transaction do
      @time_entries.each do |t|
        unless t.destroy && t.destroyed?
          raise ActiveRecord::Rollback
        end
      end
    end

    respond_to do |format|
      format.html {
        if destroyed
          flash[:notice] = l(:notice_successful_delete)
        else
          flash[:error] = l(:notice_unable_delete_time_entry)
        end
        redirect_to(:back)
        #redirect_back_or_default project_time_entries_path(@projects.first)
      }
      format.api  {
        if destroyed
          render_api_ok
        else
          render_validation_errors(@time_entries)
        end
      }
    end
  end

private

  def find_time_entry
    @time_entry = TimeEntry.find(params[:id])
    unless @time_entry.editable_by?(User.current)
      render_403
      return false
    end
    @project = @time_entry.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_time_entries
    @time_entries = TimeEntry.find_all_by_id(params[:id] || params[:ids])
    raise ActiveRecord::RecordNotFound if @time_entries.empty?
    @projects = @time_entries.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def set_flash_from_bulk_time_entry_save(time_entries, unsaved_time_entry_ids)
    if unsaved_time_entry_ids.empty?
      flash[:notice] = l(:notice_successful_update) unless time_entries.empty?
    else
      flash[:error] = l(:notice_failed_to_save_time_entries,
                        :count => unsaved_time_entry_ids.size,
                        :total => time_entries.size,
                        :ids => '#' + unsaved_time_entry_ids.join(', #'))
    end
  end

  def find_optional_project_for_new_time_entry
    if (project_id = (params[:project_id] || params[:time_entry] && params[:time_entry][:project_id])).present?
      @project = Project.find(project_id)
    end
    if (issue_id = (params[:issue_id] || params[:time_entry] && params[:time_entry][:issue_id])).present?
      @issue = Issue.find_by_id(issue_id)
      @project ||= @issue.project
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_project_for_new_time_entry
    find_optional_project_for_new_time_entry
    if @project.nil?
      render_404
    end
  end

  def find_optional_project
    if !params[:issue_id].blank?
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
    elsif !params[:project_id].blank?
      @project = Project.find(params[:project_id])
    elsif !params[:id].blank?
      @project = Project.find(params[:id])
    #elsif params.has_key?(:ga)
      #@project = Project.where(:name => "general activity").first
    end
  end

  # Returns the TimeEntry scope for index and report actions
  def time_entry_scope
    if @project && @project.id!=@general_activity_project.id
      scope = TimeEntry.visible.where(@query.statement)
    else
      #----------------------------------------------------------
      # This code is being used for get the appropriate user`s time log on Genaral activity
      final_query = User.current.admin || User.current.manager ? @query.statement : (@query.statement.nil? ?  "time_entries.user_id = #{User.current.id}" : @query.statement + " AND time_entries.user_id = #{User.current.id}")
      #----------------------------------------------------------
      scope = TimeEntry.where(final_query)
    end
    if @issue
      scope = scope.on_issue(@issue)
    elsif @project
      scope = scope.on_project(@project, Setting.display_subprojects_issues?)
    end
    scope
  end

  def parse_params_for_bulk_time_entry_attributes(params)
    attributes = (params[:time_entry] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    attributes[:custom_field_values].reject! {|k,v| v.blank?} if attributes[:custom_field_values]
    attributes
  end
end