# encoding: utf-8
#
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

module DocumentsHelper

	def activity_collection_for_select_options(time_entry=nil, project=nil)
    project ||= @project
    if project.nil?
      activities = TimeEntryActivity.shared.active
    else
      activities = project.activities
    end

    collection = []
    if time_entry && time_entry.activity && !time_entry.activity.active?
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ]
    else
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ] unless activities.detect(&:is_default)
    end
    activities.each { |a| collection << [a.name, a.id] }
    collection
  end

  def is_project_client?(project, user)
    @client = nil
    @members = project.members
    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @client = mem
        end
      end
    if (@client.present? && @client.user_id == user.id)
      return true
    else
      return false
    end
 
  end

  def find_project_clients(project,document)
    @clients = []
    @document = document
    @project = project
    @members = @project.members
    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Client'
        @clients << mem
      end
    end
    return @clients
  end 

  def find_project_managers(project,document)
    @clients = []
    @document = document
    @project = project
    @members = @project.members
    @members.each do |mem|
      @member_role = MemberRole.find_by_member_id(mem.id)
      @role = Role.find(@member_role.role_id)
      if @role.name == 'Manager'
        @clients << mem
      end
    end
    return @clients
  end 

end
