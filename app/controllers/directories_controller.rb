class DirectoriesController < ApplicationController

	before_filter :require_login, :find_project_by_project_id

  def index
    @directory = Directory.where(:project_id => @project.id)
  end

  def new
    @directory = Directory.where(:project_id => @project.id)

    if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.where("project_id = ?", @project.id)
    end
    
    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]

  end

  def create

    Rails.logger.debug "create values"
    Rails.logger.debug @project.inspect

    #render text: params[:post].inspect

    #record = Directory.new(:project_id => @project.id, :name => params[:name])
    #record.save
  if !params[:name].empty?
    directoryexists = Directory.where('project_id=? AND name=?', @project.id, params[:name]).count
  if directoryexists > 0
    flash[:error] = "Directory with name #{params[:name]} is already exists!. Use some other name for directory creation."
    redirect_to new_project_directory_path(@project)
  else
    directory = Directory.new(:project_id => @project.id, :name => params[:name])
    if directory.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to new_project_directory_path(@project)
    else
      flash[:error] = "Directory name is mandatory!"
      redirect_to new_project_directory_path(@project)
    end
  end
  else
    flash[:error] = "Directory name is mandatory!"
    redirect_to new_project_directory_path(@project)
  end

  
    #sql = "INSERT INTO directory ('project_id', 'name') VALUES ('1','testing')"
    #ActiveRecord::Base.connection.execute(sql) 

   #  raw_sql = "INSERT INTO Directory ('user_id', 'something_else') VALUES ('','') "

  	 #record = Directory.new(:project_id => 1, :name => 'testing')
     #record.save

     
   
  	# container = (params[:version_id].blank? ? @project : @project.versions.find_by_id(params[:version_id]))
   #  attachments = Attachment.attach_files(container, params[:attachments])

  	# @role = Directory.new(params[:name])
   #  if request.post? && @role.save
   #    # workflow copy
   #    if !params[:copy_workflow_from].blank? && (copy_from = Role.find_by_id(params[:copy_workflow_from]))
   #      @role.workflow_rules.copy(copy_from)
   #    end
   #    flash[:notice] = l(:notice_successful_create)
   #    redirect_to roles_path
   #  else
   #    @roles = Role.sorted.all
   #    render :action => 'new'
   #  end

  end

  def edit
    Rails.logger.debug "edit params values"
    Rails.logger.debug params.inspect
    @directoryinfo = Directory.find(params[:id])

    if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.where("project_id = ?", @project.id)
      end

    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
    
  end

  def update
    Rails.logger.debug "update params values"
    Rails.logger.debug params.inspect
    @directoryval = Directory.find(params[:id])
  if !params[:name].empty?
    if @directoryval.update_attributes(:name => params[:name])
      flash[:notice] = l(:notice_successful_update)
      redirect_to new_project_directory_path(@project)
    end
  else
    flash[:notice] = "Directory name should not be empty!"
    redirect_to(:back)
  end

  end

  def destroy    
    @directory = Directory.find(params[:id])
    @attachments = Attachment.where('directory_id=?',@directory.id)   
    @attachments.destroy_all
    @directory.destroy
    if params.has_key?(:ajax)
      render :text=>"Successfully remove directory and attachments associated to it."
    else
      redirect_to new_project_directory_path(@project)
    end
  end

end