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

class IssuesController < ApplicationController
  menu_item :new_issue, :only => [:new, :create]
  default_search_scope :issues
  before_filter :require_login
  before_filter :find_issue, :only => [:show, :edit, :update]
  before_filter :find_issues, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :find_project, :only => [:index, :new, :create, :update_form]
  before_filter :authorize, :except => [:index]
  before_filter :find_optional_project, :only => [:index]
  before_filter :check_for_default_issue_status, :only => [:new, :create]
  before_filter :build_new_issue_from_params, :only => [:index, :show, :new, :create, :update_form]
  accept_rss_auth :index, :show
  accept_api_auth :index, :show, :create, :update, :destroy

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :timelog
  include Redmine::Export::PDF

  def index

    #To check current is reporter and then allow to close the bug if no entires
    reporter_role_id= Role.find_by_name('Reporter').id
    @reporter_roles = MemberRole.where('role_id=?',reporter_role_id)
    @reporter  = User.current.members.where('project_id=? and id in (?)',@project.id,@reporter_roles.collect(&:member_id))

    #To check current is client and then allow to close the bug if no entires
    client_role_id= Role.find_by_name('Client').id
    @client_roles = MemberRole.where('role_id=?',client_role_id)
    @client  = User.current.members.where('project_id=? and id in (?)',@project.id,@client_roles.collect(&:member_id))

    @params_count = params.count
    @fixedid = Version.where("project_id = ?",@project.id) #.last if @project.versions.any?
    if params[:format]=="csv"
      params[:tid] == "2" ? retrieve_todo_query : retrieve_issue_query
      #retrieve_query_org #need to remove this code in helper
    else
    retrieve_query
    end
    @is_any_sprint_open = @fixedid.first.status == "open" ? true : false;
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a
    
    if @query.valid?
      case params[:format]
      when 'csv', 'pdf'
        @limit = Setting.issues_export_limit.to_i
      when 'atom'
        @limit = Setting.feeds_limit.to_i
      when 'xml', 'json'
        @offset, @limit = api_offset_and_limit
      else
        @limit = per_page_option
      end

      if User.current.allowed_to?(:view_time_entries, @project)
        @total_hours = TimeEntry.where("project_id = ?", @project.id)
      end
      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version, :time_entries, :custom_values],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)

      severity_id = CustomField.find_by_type_and_name("IssueCustomField","Severity").id    
      @severity_values = CustomValue.where("custom_field_id=? and customized_id in (?)",severity_id,@issues.collect(&:id))
      
      @issue_count_by_group = @query.issue_count_by_group

      @project_general = @general_activity_project
    cond_general = @project_general.project_condition(Setting.display_subprojects_issues?)
    if User.current.allowed_to?(:view_time_entries, @project_general)
      @total_hours_general = TimeEntry.visible.sum(:billable, :include => :project, :conditions => cond_general).to_f
    end

    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
    
    export_filename = "#{@project.name}_#{Date.today.strftime("%d%m%Y")}"
      respond_to do |format|
        format.html { render :template => 'issues/index', :layout => !request.xhr? }
        format.api  {
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
        }
        format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
        format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => "#{export_filename}.csv") }
        format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => "#{export_filename}.pdf") }
      end
    else
      respond_to do |format|
        format.html { render(:template => 'issues/index', :layout => !request.xhr?) }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def ajax_create
    @fixedid = Version.where("project_id = ?",@project.id) #.last if @project.versions.any? 
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, per_page_option, params['page']
      @offset ||= @issue_pages.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)
      severity_id = CustomField.find_by_type_and_name("IssueCustomField","Severity").id    
      @severity_values = CustomValue.where("custom_field_id=? and customized_id in (?)",severity_id,@issues.collect(&:id))
      @issue_count_by_group = @query.issue_count_by_group
      respond_to do |format|
        format.html { render :partial => 'issues/issues', :layout => !request.xhr? }
      end
    else
      respond_to do |format|
        format.html { render(:partial => 'issues/issues', :layout => !request.xhr?) }        
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def show
    if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.where("project_id = ?", @project.id)
    end

    @sprints = Version.where(:project_id => @project.id)
    @is_any_sprint_open = @sprints.collect(&:status).include?('open')

    @journals = @issue.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    @changesets = @issue.changesets.visible.all
    @changesets.reverse! if User.current.wants_comments_in_reverse_order?

    @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @priorities = IssuePriority.active
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @relation = IssueRelation.new
    @issues = Issue.recently_updated.limit(5)

    respond_to do |format|
      format.html {
        retrieve_previous_and_next_issue_ids
        render :template => 'issues/show'
      }
      format.api
      format.atom { render :template => 'journals/index', :layout => false, :content_type => 'application/atom+xml' }
      format.pdf  {
        pdf = issue_to_pdf(@issue, :journals => @journals)
        send_data(pdf, :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf")
      }
    end
  end

  # Add a new issue
  # The new issue will be created from an existing one if copy_from parameter is given
  def new
    respond_to do |format|
      format.html { render :action => 'new', :layout => !request.xhr? }
    end
  end

  def create
     #To check current is reporter and then allow to close the bug if no entires
    reporter_role_id= Role.find_by_name('Reporter').id
    @reporter_roles = MemberRole.where('role_id=?',reporter_role_id)
    @reporter  = User.current.members.where('project_id=? and id in (?)',@project.id,@reporter_roles.collect(&:member_id))
    #To check current is client and then allow to close the bug if no entires
    client_role_id= Role.find_by_name('Client').id
    @client_roles = MemberRole.where('role_id=?',client_role_id)
    @client  = User.current.members.where('project_id=? and id in (?)',@project.id,@client_roles.collect(&:member_id))
    
    call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    message = ""
    message = "Subject is mandatory!" if params[:issue][:subject] == "" 
    message = "Subject and Estimated Hours is mandatory!" if params[:issue][:estimated_hours] == "" && params[:tid] == "2"
    message = "Severity is mandatory!" if params[:issue][:custom_field_values] && params[:issue][:custom_field_values].first[1] =="" 
    message = "Subject and Severity is mandatory!" if params[:issue][:subject] == "" && params[:issue][:custom_field_values] && params[:issue][:custom_field_values].first[1] =="" 

     
    
    check = false
    issue_status = IssueStatus.find_by_id(params[:issue][:status_id])
    if issue_status
      issue_status.name == "Closed" ? params[:issue][:done_ratio] = "100" : params[:issue][:done_ratio]
      issue_status.name.capitalize == "Re-open" ? params[:issue][:done_ratio] = "0" : params[:issue][:done_ratio]
    end 
    
    if params[:issue][:custom_field_values] && params[:issue][:custom_field_values].first[1] !="" &&  ((params[:issue][:custom_field_values].first[1].to_i).is_a? Numeric)
      if (params[:issue][:custom_field_values].first[1].to_i).between?(0,4)
       check = true
      else  
        message = "Severity should be in the range of [1-5]"  
      end
    end
    if params[:tracker_id]=='2'
      estimated_hrs = params[:issue][:estimated_hours]
      validate_estimated_hours(params[:issue][:estimated_hours])
      if params[:issue][:subject] == ""
        message = "Subject is mandatory!"
      elsif estimated_hrs == "" 
        message = "Estimated Hours is mandatory!"
      elsif params[:issue][:estimated_hours] == -1
        message = "Invalid Estimated Time Format."
      else
        check=true #need not check the serverity for creating issue/feature
      end
      
    end  
    if check && @issue.save
      call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
      respond_to do |format|
        format.html {
          render_attachment_warning_if_needed(@issue)
          #flash[:notice] = "Successfully added!"
          if params[:continue]
            attrs = {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?}
            redirect_to new_project_issue_path(@issue.project, :issue => attrs)
          else
            ajax_create
            #redirect_to :controller => 'issues', :action => 'index', :project_id =>@project, :tid => params["tracker_id"]
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
      end
      return
    else
      
      respond_to do |format|
        format.html { 
          #flash[:error] = "Subject is mandatory!"
	  render :text => message
          #redirect_to :controller => 'issues', :action => 'index', :project_id =>@project, :tid => params["tracker_id"]
        }
      end

    end
  end

  def create_by_csv  
    IssueObserver.disabled=true  
    if params['file']
      name =  params['file'].original_filename     
      content_type = params['file'].content_type
      if content_type == "text/csv" || content_type == "application/vnd.ms-excel"
        directory = "public/tmp"
        path = File.join(directory, name) # create the file path
        File.open(path, "wb") { |f| f.write(params['file'].read) } # write the file
        @upload_result = false;
        iterate_csv(path,params)
        File.delete(path)
        respond_to do |format|
            format.html { 
              if @upload_result
                redirect_to :back, :flash => { :notice => "Imported Successfully", :import_action => "true" }
                send_bulk_issue_upload_email(@issues,@project_name,@project_identifier, @issues_author, @issues_fixed_version,@issues_recepients, params["tracker_id"])
              else
                flash[:error] = "Import CSV Failed! Please check with sample file format."
                redirect_to :back, :flash => { :error => "Import CSV Failed! Please check with sample file format.", :import_action => "false" }
              end
              
            }
        end
     else
      respond_to do |format|
            format.html {
                redirect_to :back, :flash => { :error => "Please upload only csv format!", :import_action => "false" }
            }
        end
     end
    else
      respond_to do |format|
            format.html {
                redirect_to :back, :flash => { :error => "Please choose a file", :import_action => "false" }
            }
      end
    end
  end

  def iterate_csv(path,params)
    @project_name = nil
    @issues = []
    CSV.foreach(path, headers: true) do |row|
         hash_data = row.to_hash
         if hash_data["Subject"] && hash_data["Description"] && hash_data["EstimatedHours"] && hash_data["Severity"]
           tracker_id = params["tracker_id"]
           project_id = params["project_id"]
           fixed_version_id = params["import_fixed_version_id"]
           @issue = Issue.new
           @project = Project.find(project_id)
           @issue.project = @project
           set_issue_params(tracker_id,fixed_version_id,hash_data)
          @issue.author ||= User.current
          if hash_data["AssignedTo"] != "" && !hash_data["AssignedTo"].nil?
           @issue.assigned_to = User.find_by_login(hash_data["AssignedTo"])
          end
          # Tracker must be set before custom field values
          @issue.tracker ||= @project.trackers.find(tracker_id)
          if @issue.tracker.nil?
            render_error l(:error_no_tracker_in_project)
            return false
          end
          @issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?
          @issue.safe_attributes = params[:issue]

          @priorities = IssuePriority.active
          @allowed_statuses = @issue.new_statuses_allowed_to(User.current, true)
          @available_watchers = (@issue.project.users.sort + @issue.watcher_users).uniq
          
          if @project_name.nil?
             @project_name = @issue.project.name
             @project_identifier = @issue.project.identifier
             @issues_author = @issue.author.login
             @issues_fixed_version = @issue.fixed_version.name
             @issues_recepients = @issue.recipients
          end
          @upload_result = @issue.save!
          @issues << @issue
        else
          return false
        end
    end
  end

  def set_issue_params(tracker_id,fixed_version_id,hash_data)
    subject = hash_data["Subject"] == "" || hash_data["Subject"].nil?   ? "No Subject" : hash_data["Subject"]
    estimated_hours = hash_data["EstimatedHours"].to_i == 0  ? 0 : hash_data["EstimatedHours"].to_i
    params["issue"] = { "priority_id"=>"2", 
                        "fixed_version_id"=>fixed_version_id, 
                        "subject"=> subject, 
                        "description" => hash_data["Description"],
                        "estimated_hours"=> estimated_hours
                      }
    if tracker_id == "1"
        if (hash_data["Severity"] != "" && !hash_data["Severity"].nil? )
          if(hash_data["Severity"].to_i >= 0 && hash_data["Severity"].to_i <= 4)
            params["issue"]["custom_field_values"] = {"6" => hash_data["Severity"]}
          else
            params["issue"]["custom_field_values"] = {"6" => "0"}
          end
        else
          params["issue"]["custom_field_values"] = {"6" => "0"}
        end
    end
  end

  def send_bulk_issue_upload_email(issues,project_name,project_identifier,author,fixed_version,recipients,tracker_id)
    Thread.new { Mailer.issue_bulk_add(issues,project_name,project_identifier,author,fixed_version,recipients,tracker_id).deliver }
  end

  def edit
    return unless update_issue_from_params
    version = Version.find(@issue.fixed_version_id)
    if version.status == "closed"
      redirect_back_or_default issue_path(@issue)      
    else
      respond_to do |format|
        format.html { }
        format.xml  { }
      end
    end
  end

  def update

    #if params[:mins]!="0"      
      #params[:issue][:estimated_hours] = ((params[:issue][:estimated_hours] << params[:mins]).to_f)/100      
    #end

    #To check current is reporter and then allow to close the bug if no entires
    reporter_role_id= Role.find_by_name('Reporter').id
    @reporter_roles = MemberRole.where('role_id=?',reporter_role_id)
    @reporter  = User.current.members.where('project_id=? and id in (?)',@project.id,@reporter_roles.collect(&:member_id))

    #To check current is client and then allow to close the bug if no entires
    client_role_id= Role.find_by_name('Client').id
    @client_roles = MemberRole.where('role_id=?',client_role_id)
    @client  = User.current.members.where('project_id=? and id in (?)',@project.id,@client_roles.collect(&:member_id))

    @estimated_hours = params[:issue][:estimated_hours]

    if params[:issue][:tracker_id]=='2'
      validate_estimated_hours(params[:issue][:estimated_hours])
    elsif params[:issue][:estimated_hours] == "" && params[:issue][:tracker_id]=='1'
      params[:issue][:estimated_hours] = 0
    elsif params[:issue][:estimated_hours].to_f == 0.0  && params[:issue][:tracker_id]=='1'
      params[:issue][:estimated_hours] = 0
    elsif params[:issue][:estimated_hours].to_f != 0.0  && params[:issue][:tracker_id]=='1'
      validate_estimated_hours(params[:issue][:estimated_hours])
    end 

    @entries=TimeEntry.where(:issue_id =>params[:id])
    issue_status = IssueStatus.find_by_id(params[:issue][:status_id])
    if issue_status
      issue_status.name.capitalize == "Closed" ? params[:issue][:done_ratio] = "100" : params[:issue][:done_ratio]
      issue_status.name.capitalize == "Re-open" ? params[:issue][:done_ratio] = "0" : params[:issue][:done_ratio]
    end  

    return unless update_issue_from_params
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    saved = false
    begin
        #saved = @issue.save_issue_with_child_records(params, @time_entry)
        if issue_status.name.capitalize == "Closed"
          
          unless @reporter.empty? && @client.empty?
            if params["issue"]["tracker_id"] == "2"
                flash[:error] = "No time entries found for this task. Please make sure to add time entry before closing."
            else
              saved = @issue.save_issue_with_child_records(params, @time_entry)
            end
          else
              if @entries.present?
                saved = @issue.save_issue_with_child_records(params, @time_entry)
              else
               flash[:error] = "No time entries found for this task. Please make sure to add time entry before closing."
              end
          end
        else          
          saved = @issue.save_issue_with_child_records(params, @time_entry)
        end
    rescue ActiveRecord::StaleObjectError
      @conflict = true
      if params[:last_journal_id]
        @conflict_journals = @issue.journals_after(params[:last_journal_id]).all
        @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
      end
    end

    if saved
      render_attachment_warning_if_needed(@issue)
      flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

      respond_to do |format|
        format.html { redirect_back_or_default issue_path(@issue) }
        format.api  { render_api_ok }
      end
    else
      respond_to do |format|
        format.html { render :action => 'edit' }
        if(@issue.estimated_hours == -1)
          @issue.estimated_hours = @estimated_hours
        end
        format.api  { render_validation_errors(@issue) }
      end
    end
  end

  def validate_estimated_hours(eth)
    estimated_hours = eth.to_f
    estimated_hrs = estimated_hours.to_s.split('.')[0]
    estimated_mins = estimated_hours.to_s.split('.')[1]
    case estimated_mins.to_i
    when 25
    when 50
    when 75
    when 5
    when 0
      estimated_hrs == "0" ? params[:issue][:estimated_hours] = "" : ""
    else
      params[:issue][:estimated_hours] = -1
    end
  end

  # Updates the issue form when changing the project, status or tracker
  # on issue creation/update
  def update_form
  end

  # Bulk edit/copy a set of issues
  def bulk_edit
    @issues.sort!
    @copy = params[:copy].present?
    @notes = params[:notes]

    if User.current.allowed_to?(:move_issues, @projects)
      @allowed_projects = Issue.allowed_target_projects_on_move
      if params[:issue]
        @target_project = @allowed_projects.detect {|p| p.id.to_s == params[:issue][:project_id].to_s}
        if @target_project
          target_projects = [@target_project]
        end
      end
    end
    target_projects ||= @projects

    if @copy
      @available_statuses = [IssueStatus.default]
    else
      @available_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)
    end
    @custom_fields = target_projects.map{|p|p.all_issue_custom_fields}.reduce(:&)
    @assignables = target_projects.map(&:assignable_users).reduce(:&)
    @trackers = target_projects.map(&:trackers).reduce(:&)
    @versions = target_projects.map {|p| p.shared_versions.open}.reduce(:&)
    @categories = target_projects.map {|p| p.issue_categories}.reduce(:&)
    if @copy
      @attachments_present = @issues.detect {|i| i.attachments.any?}.present?
      @subtasks_present = @issues.detect {|i| !i.leaf?}.present?
    end

    @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)
    render :layout => false if request.xhr?
  end

  def bulk_update
    #To check current is reporter and then allow to close the bug if no entires
    reporter_role_id= Role.find_by_name('Reporter').id
    @reporter_roles = MemberRole.where('role_id=?',reporter_role_id)
    @reporter  = User.current.members.where('project_id=? and id in (?)',params[:project_id],@reporter_roles.collect(&:member_id))
    #To check current is client and then allow to close the bug if no entires
    client_role_id= Role.find_by_name('Client').id
    @client_roles = MemberRole.where('role_id=?',client_role_id)
    @client  = User.current.members.where('project_id=? and id in (?)',params[:project_id],@client_roles.collect(&:member_id))
    
    @issues.sort! 
    issue_status = IssueStatus.find_by_id(params[:issue][:status_id])
      if issue_status
       if @client.empty?
        if issue_status.name.capitalize == "Closed" && @reporter.empty?
          filtered_ids = params[:ids].delete_if {|id| (TimeEntry.where(:issue_id =>id)).empty? }
          params["ids"] = filtered_ids
          if filtered_ids.empty? 
            flash[:error] = "No time entries found for selected tasks/bugs. Please make sure to add time entry before closing."
          end
        end
       end
      end
      if issue_status
        issue_status.name.capitalize == "Closed" ? params[:issue][:done_ratio] = "100" : params[:issue][:done_ratio]
        issue_status.name.capitalize == "Re-open" ? params[:issue][:done_ratio] = "0" : params[:issue][:done_ratio]
      end
    @copy = params[:copy].present?
    

    attributes = parse_params_for_bulk_issue_attributes(params)
    unsaved_issue_ids = []
    moved_issues = []
    if @copy && params[:copy_subtasks].present?
      # Descendant issues will be copied with the parent task
      # Don't copy them twice
      @issues.reject! {|issue| @issues.detect {|other| issue.is_descendant_of?(other)}}
    end
    @issues.each do |issue|
      issue.reload
      if @copy
        issue = issue.copy({},
          :attachments => params[:copy_attachments].present?,
          :subtasks => params[:copy_subtasks].present?
        )
      end 
      journal = issue.init_journal(User.current, params[:notes])
      issue.safe_attributes = attributes

      call_hook(:controller_issues_bulk_edit_before_save, { :params => params, :issue => issue })
      if issue.save
        moved_issues << issue
      else
        logger.info "issue could not be updated or copied: #{issue.errors.full_messages}" if logger && logger.info
        # Keep unsaved issue ids to display them in flash error
        unsaved_issue_ids << issue.id
      end
    end
    set_flash_from_bulk_issue_save(@issues, unsaved_issue_ids)
    if params[:follow]
      if @issues.size == 1 && moved_issues.size == 1
        redirect_to issue_path(moved_issues.first)
      elsif moved_issues.map(&:project).uniq.size == 1
        redirect_to project_issues_path(moved_issues.map(&:project).first)
      end
    else
      if request.xhr?
        render :text => "Successfully updated."
      else
        if params["issue"]["is_quick_close"] == "true"
          redirect_to :back #_or_default _project_issues_path(@project)
        else
          redirect_back_or_default _project_issues_path(@project)
        end
      end
  end
  
    
  end

  def destroy
    @hours = TimeEntry.sum(:hours, :conditions => ['issue_id IN (?)', @issues]).to_f
    @unapproved_hours = TimeEntry.sum(:hours, :conditions => ['issue_id = ? AND approval_status IS NULL', params[:id]])
    if @hours > 0
      case params[:todo]
      when 'destroy'
        # nothing to do
      when 'nullify'
        TimeEntry.update_all('issue_id = NULL', ['issue_id IN (?)', @issues])
      when 'reassign'
        reassign_to = @project.issues.find_by_id(params[:reassign_to_id])
        if reassign_to.nil?
          flash.now[:error] = l(:error_issue_not_found_in_project)
          return
        elsif params[:reassign_to_id] == params[:id]
          flash.now[:error] = "Current issue/task id and assigned id should not be same."
          return
        else
          TimeEntry.update_all("issue_id = #{reassign_to.id}", ['issue_id IN (?)', @issues])
        end
      else
        # display the destroy form if it's a user request
        return unless api_request?
      end
    end
    @issues.each do |issue|
      begin
        issue.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
        # nothing to do, issue was already deleted (eg. by a parent)
      end
    end
    case params[:todo]
      when 'reassign'
        flash[:notice] = "Successfully deleted and hours reassigned to "+params[:reassign_to_id]
      else
        flash[:notice] = l(:notice_successful_delete)
    end

    respond_to do |format|
      format.html { redirect_back_or_default :controller => 'issues', :action => 'index', :project_id =>@project, :tid => params["tid"] } 
      format.api  { render_api_ok }
    end
  end

  private

  def find_project
    project_id = params[:project_id] || (params[:issue] && params[:issue][:project_id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def retrieve_previous_and_next_issue_ids
    retrieve_query_from_session
    if @query
      sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns, 'issues_index_sort')
      limit = 500
      issue_ids = @query.issue_ids(:order => sort_clause, :limit => (limit + 1), :include => [:assigned_to, :tracker, :priority, :category, :fixed_version])
      if (idx = issue_ids.index(@issue.id)) && idx < limit
        if issue_ids.size < 500
          @issue_position = idx + 1
          @issue_count = issue_ids.size
        end
        @prev_issue_id = issue_ids[idx - 1] if idx > 0
        @next_issue_id = issue_ids[idx + 1] if idx < (issue_ids.size - 1)
      end
    end
  end

  # Used by #edit and #update to set some common instance variables
  # from the params
  # TODO: Refactor, not everything in here is needed by #edit
  def update_issue_from_params
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @time_entry.attributes = params[:time_entry]

    @issue.init_journal(User.current)

    issue_attributes = params[:issue]
    if issue_attributes && params[:conflict_resolution]
      case params[:conflict_resolution]
      when 'overwrite'
        issue_attributes = issue_attributes.dup
        issue_attributes.delete(:lock_version)
      when 'add_notes'
        issue_attributes = issue_attributes.slice(:notes)
      when 'cancel'
        redirect_to issue_path(@issue)
        return false
      end
    end
    @issue.safe_attributes = issue_attributes
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    true
  end

  # TODO: Refactor, lots of extra code in here
  # TODO: Changing tracker on an existing issue should not trigger this
  def build_new_issue_from_params
    if params[:id].blank?
      @issue = Issue.new
      if params[:copy_from]
        begin
          @copy_from = Issue.visible.find(params[:copy_from])
          @copy_attachments = params[:copy_attachments].present? || request.get?
          @copy_subtasks = params[:copy_subtasks].present? || request.get?
          @issue.copy_from(@copy_from, :attachments => @copy_attachments, :subtasks => @copy_subtasks)
        rescue ActiveRecord::RecordNotFound
          render_404
          return
        end
      end
      @issue.project = @project
    else
      @issue = @project.issues.visible.find(params[:id])
    end
    @issue.project = @project
    @issue.author ||= User.current
    # Tracker must be set before custom field values
    @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)
    if @issue.tracker.nil?
      render_error l(:error_no_tracker_in_project)
      return false
    end
    @issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?
    @issue.safe_attributes = params[:issue]

    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current, true)
    @available_watchers = (@issue.project.users.sort + @issue.watcher_users).uniq
  end

  def check_for_default_issue_status
    if IssueStatus.default.nil?
      render_error l(:error_no_default_issue_status)
      return false
    end
  end

  def parse_params_for_bulk_issue_attributes(params)
    attributes = (params[:issue] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    if custom = attributes[:custom_field_values]
      custom.reject! {|k,v| v.blank?}
      custom.keys.each do |k|
        if custom[k].is_a?(Array)
          custom[k] << '' if custom[k].delete('__none__')
        else
          custom[k] = '' if custom[k] == '__none__'
        end
      end
    end
    attributes
  end
end
