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

desc <<-END_DESC
Send reminders about issues due in the next days.

Available options:
  * days     => number of days to remind about (defaults to 7)
  * tracker  => id of tracker (defaults to all trackers)
  * project  => id or identifier of project (defaults to all projects)
  * users    => comma separated list of user/group ids who should be reminded

Example:
  rake redmine:send_reminders days=7 users="1,23, 56" RAILS_ENV="production"
END_DESC

namespace :redmine do
  task :send_reminders => :environment do
    options = {}
    options[:days] = ENV['days'].to_i if ENV['days']
    options[:project] = ENV['project'] if ENV['project']
    options[:tracker] = ENV['tracker'].to_i if ENV['tracker']
    options[:users] = (ENV['users'] || '').split(',').each(&:strip!)

    Mailer.with_synched_deliveries do
      Mailer.reminders(options)
    end
  end

desc 'Timesheet Defaulter mail to who ever missed the filling timesheet.'
task :timesheet_reminder_mail => [:environment] do
  if (Time.now.beginning_of_week.to_date == Time.now.to_date)
    @defaulters  = []
    @users = User.where('admin = ? AND manager = ?',false,false).active # need to expel admin user.
    #@users = User.find_all_by_id([81,104,74]) # testing purpose defined users
    start_date = Time.now-1.week
    start_date = start_date.to_date
    end_date = Time.now-3.days
    end_date = end_date.to_date
    @users.each do |user| 
      # finding user is a client or not
      members = Member.find_all_by_user_id(user.id)
      member_ids = members.map(&:id)
      member_roles = MemberRole.find_all_by_id(member_ids)
      role_ids =  member_roles.map(&:role_id)
      unless role_ids.include?(6)

      (start_date..end_date).each do |date| 
        @time_entry = TimeEntry.find_by_user_id_and_spent_on(user.id, date.strftime("%Y-%m-%d"))
          if @time_entry == nil 
             @defaulters << user unless @defaulters.include?(user)
          end
      end
      end
    end  
    p @defaulters
    if !@defaulters.empty?
      Mailer.timesheet_reminder(@defaulters.map(&:mail)).deliver
    end
  end
end


end
