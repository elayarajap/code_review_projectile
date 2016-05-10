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

class FilesController < ApplicationController
  menu_item :files
  before_filter :require_login
  before_filter :find_project_by_project_id
  before_filter :authorize

  helper :sort
  include SortHelper

  def index

    if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.where("project_id = ?", @project.id)
    end

    @sprints = Version.where(:project_id => @project.id)
    @is_any_sprint_open = @sprints.collect(&:status).include?('open')

    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]

    sort_init 'filename', 'asc'
    sort_update 'filename' => "#{Attachment.table_name}.filename",
                'created_on' => "#{Attachment.table_name}.created_on",
                'size' => "#{Attachment.table_name}.filesize",
                'downloads' => "#{Attachment.table_name}.downloads"

    @containers = [ Project.includes(:attachments).reorder(sort_clause).find(@project.id)]
    @containers += @project.versions.includes(:attachments).reorder(sort_clause).all.sort.reverse
    @directories = Directory.where(:project_id => @project.id)
    p @directories.inspect

    @jqtree_data = []    
    jqtree_counter=1
    for directory in @directories
      files_array=[]
      directory_counter = jqtree_counter
      @containers.each do |container|
        next if container.attachments.empty?
        container.attachments.find_all{|item| item.directory_id==directory.id}.each do |file|           
          jqtree_counter+=1
          files_array<<{title: file.filename, key: "#{file.id}"}          
        end
      end 
      @jqtree_data << {title: directory.name, key: 0, folder: true, children: files_array}
      jqtree_counter+=1
    end
    render :layout => !request.xhr?
  end

  def new
    @versions = @project.versions.sort
    @directories = Directory.where(:project_id => @project.id)
    if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.where("project_id = ?", @project.id)
    end
    
    @time_entry ||= TimeEntry.new(:project => @project, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
  end

  def create
    container = (params[:version_id].blank? ? @project : @project.versions.find_by_id(params[:version_id]))
    attachments = Attachment.attach_files_with_directory(container, params[:directory_id], params[:attachments])
    render_attachment_warning_if_needed(container)
    if !attachments[:files].blank?  
      if !attachments.empty? && !attachments[:files].blank? && Setting.notified_events.include?('file_added')
  Mailer.attachments_added(attachments[:files]).deliver
      end
      redirect_to project_files_path(@project)
    else
      flash[:error] = "File is mandatory!"
      redirect_to new_project_file_path(@project)
    end
  end
end
