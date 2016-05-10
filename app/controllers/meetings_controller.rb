class MeetingsController < ApplicationController

	before_filter :require_login, :find_project_by_project_id

  def index
  	@meeting = Meeting.where(:project_id => @project.id).order("id DESC")
  end

  def show
  	@meeting = Meeting.find(params[:id])
    @clients = []
    @members = @project.members

    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @clients << mem
      end
    end
    @groupmail = ''
    @groupmail = @project.group_mail_address
    if @clients.present? && !@groupmail.nil?
      clients = User.where(:id=>@clients.map(&:user_id))
      mom_details(clients, @groupmail, @meeting)
  end
  end
  def new
  	@meetingtype = MeetingType.all
    @proj_mem = @project.members
    @user_ids = @proj_mem.map(&:user_id)
    @users = User.find_all_by_id(@user_ids)
    @meeting = Meeting.where(:project_id => @project.id).order("date")
    @new_meeting = @project.meetings.build
    action_items = @new_meeting.action_items.build
    custom_attendees = @new_meeting.custom_attendees.build
    @sprints = @project.versions.where(:status => "open")
  end

   def create
    dt = params[:datetime].split(' ')
    date = params[:datetime].split(' ')[0]
    time = params[:datetime].split(' ')[1]
    params["meeting"]["date"] = date
    params["meeting"]["time"] = time
    params.delete("datetime")

    dt = params[:enddatetime].split(' ')
    date = params[:enddatetime].split(' ')[0]
    time = params[:enddatetime].split(' ')[1]
    params["meeting"]["end_date"] = date
    params["meeting"]["end_time"] = time
    params.delete("enddatetime")
    
    custom_emails = params[:meeting][:custom_emails].split(',')
   
    @meetinginfo = Meeting.new(params[:meeting])
    @meetinginfo.project_id = @project.id
    @meetinginfo.project_id = @project.id

    if check_for_email_authentication
      if @meetinginfo.save
        send_meeting_info_mail(@meetinginfo, custom_emails)
      else
        #new #calling new method for get those instance variables for render new form
        @new_meeting = @meetinginfo
        flash[:error] = "Title, Discussion summary, Start and End date are mandatory and enter valid email."
        redirect_to(:back)
      end
    else
      flash[:error] = "Client email address and project group email address are mandatory! Please check project settings and enable it"
      redirect_to(:back)
    end
  end

  def edit
  	@meetingtype = MeetingType.all
    @new_meeting = Meeting.find(params[:id])
    @proj_mem = @project.members
    @user_ids = @proj_mem.map(&:user_id)
    @users = User.find_all_by_id(@user_ids)
    @sprints = @project.versions
    #action_items = @new_meeting.action_items.build
  end

  def update
  	dt = params[:datetime].split(' ')
    date = params[:datetime].split(' ')[0]
    time = params[:datetime].split(' ')[1]
    params["meeting"]["date"] = date
    params["meeting"]["time"] = time
    params.delete("datetime")
    @meetingval = Meeting.find(params[:id])
    if @meetingval.update_attributes(params[:meeting])
      flash[:notice] = "Successfully updated"
      redirect_to project_meetings_path(@project)
      send_meeting_info_mail(@meetingval)
    else
      flash[:error] = "Title, Discussion summary and Date time are mandatory and enter valid email."
      redirect_to(:back)
    end
  end

  def destroy
  	@meeting = Meeting.find(params[:id])
    if @meeting.destroy
      flash[:notice] = "Successfully deleted!"
      redirect_to project_meetings_path(@project)
    else
      flash[:error] = "Unknown error!"
      redirect_to project_meetings_path(@project)
    end
  end

  def check_for_email_authentication
    @clients = []
    @members = @project.members
    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @clients << mem
      end
    end
    @groupmail = ''
    @groupmail = @project.group_mail_address

    if @clients.present? && !@groupmail.nil?
      return true
    else
      return false
    end
  end


  def send_meeting_info_mail(meeting, custom_emails)
    meeting = meeting
    @clients = []
    @members = @project.members

    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @clients << mem
      end
    end

    @groupmail = ''  
    
    @custom_emails = custom_emails
    @groupmail = @project.group_mail_address
    if @clients.present? && !@groupmail.nil?
      clients = User.where(:id=>@clients.map(&:user_id))
      mom_details(clients, @groupmail, meeting)
      @custom_emails.each do |cus_email| 
        @emails << {:email => cus_email, :name => cus_email.split("@")[0]} if !@custom_emails.nil?       
      end
      project_manager = User.current
      Thread.new { Mailer.send_meeting_info(project_manager,@client_names, @emails, @groupmail,@mail_subject,@meeting_title, @meeting_discussion_summary, @meeting_start_date, @meeting_end_date, @meeting_start_time, @meeting_end_time, @meeting_attendees, @meeting_custom_attendees, @meeting_action_items).deliver }
      flash[:notice] = "Meeting summary successfully saved and sent mail."
      redirect_to project_meeting_path(@project, meeting)
    else
      flash[:notice] = "Successfully added"
      redirect_to project_meetings_path(@project)
    end
  end

  def mom_details(clients, groupmail, meeting)
    @groupmail = groupmail
    @clients = clients
    @emails = []
    @clients.each do |client| 
        @emails << {:email => client.mail, :name => client.firstname}        
    end
    @emails << {:email => @groupmail, :name => @groupmail.split("@")[0]} unless @groupmail.nil?
   # @group_mail_address = @project.group_mail_address
    @account = Project.find(@project.parent_id)
    @mail_subject = @account.try(&:name)
    project_name = @project.try(:name)
    @mail_subject << " - #{project_name}" << " - Meeting summary - #{meeting.date}"
    @meeting_title = meeting.try(:title)
    @client_names = ""
      @clients.each do |client|
        slash = @clients.last == client ? "" : " / "
        @client_names = @client_names + "#{client.firstname} #{client.lastname}".capitalize + slash
      end
    @meeting_discussion_summary = meeting.try(:discussion_summary)
    @meeting_start_date = meeting.try(:date)
    @meeting_end_date = meeting.try(:end_date)
    @meeting_start_time = meeting.try(:time)
    @meeting_end_time = meeting.try(:end_time)

    @meeting_attendees = meeting.try(:attendees)
    if @meeting_attendees.class == String
       @meeting_attendees = @meeting_attendees.delete('-').split("\n").drop(1)
    end

    @meeting_custom_attendees = meeting.try(:custom_attendees)
    @meeting_action_items = meeting.try(:action_items)

  end

end
