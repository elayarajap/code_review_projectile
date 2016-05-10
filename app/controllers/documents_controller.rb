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

class DocumentsController < ApplicationController
  default_search_scope :documents
  model_object Document
  before_filter :find_project_by_project_id, :only => [:index, :new, :create]
  before_filter :find_model_object, :except => [:index, :new, :create, :delete_conversation]
  before_filter :find_project_from_association, :except => [:index, :new, :create, :delete_conversation]
  before_filter :authorize, :except => [:send_for_approval, :approve, :reject, :create_conversation, :delete_conversation]
  before_filter :require_login

  helper :attachments

    def index
      @sort_by = %w(category date title author).include?(params[:sort_by]) ? params[:sort_by] : 'category'
      documents = @project.documents.includes(:attachments, :category).all
      @ducument_category = DocumentCategory.active.sort! { |a,b| a.name.downcase <=> b.name.downcase }
      
      @sprints = Version.where(:project_id => @project.id)
      @is_any_sprint_open = @sprints.collect(&:status).include?('open')

      case @sort_by
      when 'date'
        @grouped = documents.group_by {|d| d.updated_on.to_date }
      when 'title'
        @grouped = documents.group_by {|d| d.title.first.upcase}
      when 'author'
        @grouped = documents.select{|d| d.attachments.any?}.group_by {|d| d.attachments.last.author}
      else
        @grouped = documents.group_by(&:category)
      end
    
      if User.current.allowed_to?(:view_time_entries, @project)
        @total_hours = TimeEntry.where("project_id = ?", @project.id)
      end

      @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
      @time_entry.safe_attributes = params[:time_entry]

      
      @document = @project.documents.build
      @category = @ducument_category.first
      if view_context.is_project_client?(@project, User.current)
        @documents = @project.documents.where("category_id=? and status IS NOT NULL", @category.id)
      else
        @documents = @project.documents.where(:category_id => @category.id )
      end
    
     if request.xhr?
      if view_context.is_project_client?(@project, User.current)
        @documents = @project.documents.where("category_id=? and status IS NOT NULL", params[:category_id])
      else
        @documents = @project.documents.where(:category_id => params[:category_id])
      end
      @category = DocumentCategory.find(params[:category_id])
       respond_to do |format|
        format.html { render :partial => 'documents/document', :locals=> {:documents=>@documents,:category=>@category} }
      end
        
     end
    end


  def show
    @token = params[:access_token] if params[:access_token].present?
    @attachments = @document.attachments

    @attachments_latest = Attachment.where(:container_id=>@document.id).order("created_on DESC").limit(1)

    if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.where("project_id = ?", @project.id)
    end

    @conversations = DocumentConversation.where(:document_id => @document.id).order("created_on ASC").includes(:user)

    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
  end

  def new
    @document = @project.documents.build
    @document.safe_attributes = params[:document]
  end

  def create
    @document = @project.documents.build
    @document.safe_attributes = params[:document]
    @document.save_attachments(params[:attachments])
    if @document.save
      render_attachment_warning_if_needed(@document)
      flash[:notice] = l(:notice_successful_create)
      #redirect_to project_documents_path(@project)
      redirect_to document_path(@document)
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    @document.safe_attributes = params[:document]
    if request.put? and @document.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to document_path(@document)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @document.destroy if request.delete?
    redirect_to project_documents_path(@project)
  end

  def add_attachment
    @doc_attach_count = @document.attachments.count
    if @doc_attach_count>0
      @doc_attach_content = Attachment.where(:container_id=>@document.id).last
      revisionid = @doc_attach_content.revision
      revnum = revisionid.split("R").map(&:to_i)
      @doc_attach_count = revnum[1]+1
    else
      @doc_attach_count = 1
    end
    
    @doc_attach = "R#{@doc_attach_count}"

    attachments = Attachment.attach_files_revision(@document, @doc_attach, params[:attachments])
    render_attachment_warning_if_needed(@document)

    if attachments.present? && attachments[:files].present? && Setting.notified_events.include?('document_added')
      Mailer.attachments_added(attachments[:files]).deliver
    end
    flash[:error] ="Please upload file before adding." if params[:attachments].nil?
    redirect_to document_path(@document)
  end
# below action is useful for sending a approval mail to the project client.
  def send_for_approval
    @clients = []
    @author = User.current
    @document = Document.find(params[:id])
    @project = Project.find(@document.project_id)
    @members = @project.members
    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @clients << mem
        end
      end 
    if @clients.present?
      clients = User.where(:id=>@clients.map(&:user_id))
      uniq_token = Digest::MD5.hexdigest(Time.now.to_i.to_s + rand(999999999).to_s)
      @document.update_attributes(:token => uniq_token) #, :client_id => client.id )
      @url = Setting.app + "/documents/#{@document.id}?access_token=#{uniq_token}"
      Thread.new { Mailer.document_approval_mail(clients, @url, @document, @project,@author).deliver }
      @document.update_attributes(:status => "request")
      flash[:notice] = "Approval mail successfully sent to the client."
      redirect_to document_path(@document)
    else
      flash[:error] = "No client assigned under this project."
      redirect_to document_path(@document)
    end
  end 

  def approve
    @document = Document.find(params[:id])
    @document.update_attributes(:terms => 1, :approved => 1, :status => "approved", :comment => params[:value],:client_id=>User.current.id) unless @document.client_id.present?
    #flash[:notice] ="Document approved successfully."
    render :json => @document
  end

  def reject
    @document = Document.find(params[:id])
    @document.update_attributes(:terms => 0, :status => "rejected", :comment => params[:value])
    #flash[:notice] ="Document rejected."
    render :json => @document
  end

  # Methods for conversation in the document page by managers and clients

  def create_conversation
    @document_conversation = DocumentConversation.new(:comment => params[:value])
    @document_conversation.document_id = @document.id
    @document_conversation.user_id = User.current.id

    @conversations = DocumentConversation.where(:document_id => @document.id).order("created_on ASC").includes(:user)
    @doc_save = @document_conversation.save
    render 'create_conversation.js.erb' 
  end

  def delete_conversation
    @delete_conversation = DocumentConversation.find(params[:value].to_i)
    @doc_des = @delete_conversation.destroy
    @document = Document.find(params[:value1])
    @conversations = DocumentConversation.where(:document_id => params[:value1].to_i).order("created_on ASC").includes(:user)
    render 'delete_conversation.js.erb'
  end

  # Methods for conversation in the document page by managers and clients ends here
 
end
