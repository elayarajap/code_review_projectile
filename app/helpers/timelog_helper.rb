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

module TimelogHelper
  include ApplicationHelper

  def render_timelog_breadcrumb
    links = []
    links << link_to(l(:label_project_all), {:project_id => nil, :issue_id => nil})
    links << link_to(h(@project), {:project_id => @project, :issue_id => nil}) if @project
    if @issue
      if @issue.visible?
        links << link_to_issue(@issue, :subject => false)
      else
        links << "##{@issue.id}"
      end
    end
    breadcrumb links
  end

  # Returns a collection of activities for a select field.  time_entry
  # is optional and will be used to check if the selected TimeEntryActivity
  # is active.
  def activity_collection_for_select_options(time_entry=nil, project=nil)
    project ||= @project
    if project.nil?
      activities = TimeEntryActivity.shared.active
    else
      #--------------------------------------------#
      if project.name=='Human Resources'
        activities = project.activities.where(:name=>'Human Resources')
      else
        activities = project.activities
      end
      #----------------------------------------------#
    end

    collection = []
    #----------------------------------------#
    unless project.name == 'Human Resources'
      #--------------------------------------------#
        if time_entry && time_entry.activity && !time_entry.activity.active?
          collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ]
        else
          collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ] unless activities.detect(&:is_default)
        end
    end
    activities.each { |a| collection << [a.name, a.id] }
    collection
  end

  def select_hours(data, criteria, value)
    if value.to_s.empty?
      data.select {|row| row[criteria].blank? }
    else
      data.select {|row| row[criteria].to_s == value.to_s}
    end
  end

  def sum_hours_custom(data)    
    #Modified by himanth for computing sum of hours along with minutes
    TimeEntry.sum_hours(data.map{|hash| hash['hours'].to_f.round(2)})    
  end

  def sum_hours(data)
    sum = 0
    data.each do |row|
      sum += row['hours'].to_f
    end
    sum
  end

  def options_for_period_select(value)
    options_for_select([[l(:label_all_time), 'all'],
                        [l(:label_today), 'today'],
                        [l(:label_yesterday), 'yesterday'],
                        [l(:label_this_week), 'current_week'],
                        [l(:label_last_week), 'last_week'],
                        [l(:label_last_n_weeks, 2), 'last_2_weeks'],
                        [l(:label_last_n_days, 7), '7_days'],
                        [l(:label_this_month), 'current_month'],
                        [l(:label_last_month), 'last_month'],
                        [l(:label_last_n_days, 30), '30_days'],
                        [l(:label_this_year), 'current_year']],
                        value)
  end

  def format_criteria_value(criteria_options, value)
    if value.blank?
      "[#{l(:label_none)}]"
    elsif k = criteria_options[:klass]
      obj = k.find_by_id(value.to_i)
      if obj.is_a?(Issue)
        obj.visible? ? "#{obj.tracker} ##{obj.id}: #{obj.subject}" : "##{obj.id}"
      else
        obj
      end
    else
      format_value(value, criteria_options[:format])
    end
  end

  def report_to_csv(report)
    decimal_separator = l(:general_csv_decimal_separator)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # Column headers
      headers = report.criteria.collect {|criteria| l(report.available_criteria[criteria][:label]) }
      headers += report.periods
      headers << l(:label_total_time)
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(
                                    c.to_s,
                                    l(:general_csv_encoding) ) }
      # Content
      report_criteria_to_csv(csv, report.available_criteria, report.columns, report.criteria, report.periods, report.hours)
      # Total row
      str_total = Redmine::CodesetUtil.from_utf8(l(:label_total_time), l(:general_csv_encoding))
      row = [ str_total ] + [''] * (report.criteria.size - 1)
      total = 0
      report.periods.each do |period|
        sum = sum_hours(select_hours(report.hours, report.columns, period.to_s))
        total += sum.to_f
        row << (sum.to_f > 0 ? ("%.2f" % sum).gsub('.',decimal_separator) : '')
      end
      row << ("%.2f" % total).gsub('.',decimal_separator)
      csv << row
    end
    export
  end
 
  def is_project_manager(user_id, project_id)
    member = Member.where(:user_id => user_id, :project_id => project_id )
    member_role = MemberRole.find_by_member_id(member.first.id)
    role_name = Role.find(member_role.role_id).name
    role_name
  end  



  def retrieve_query_timelog
    user_in_group_array = []
    for user_in_group in @user_in_group_filter
      user_in_group_array << "#{user_in_group.id}"
    end
        params["utf8"] = "✓"
        params["f"] = ["spent_on", "user_id"]
        params["op"] = {"spent_on"=>"*", "user_id"=>"="}
        params["v"] = {"user_id"=>user_in_group_array}
        params["action"] = "index"
        params["controller"] = "timelog"
  end

  def is_locked_or_closed_or_opened(version_id)
    status = Version.find_by_id(version_id).try(:status)
    is_locked = (status == "locked" || status == "closed") ? true : false
  end

  def to_json(options = nil) 
      hash = as_json(options)

      result = '{'
      result << hash.map do |key, value|
        "#{ActiveSupport::JSON.encode(key.to_s)}:#{ActiveSupport::JSON.encode(value, options)}"
      end * ','
      result << '}'
  end


  def get_graph_data(report,hours,level)

    graph_final_data = []
    graph_data = {}
    criterias=report.criteria
    #report.criteria.each_with_index do |criteria, level|
    unless report.hours.nil?
        report.hours.collect {|h| h[criterias[level]].to_s}.uniq.each do |value| 
           hours_for_value = select_hours(hours, criterias[level], value)
           legend = h(format_criteria_value(@report.available_criteria[criterias[level]], value))
           graph_data ={:data =>[], :name =>legend} if level == 0

           report.periods.each do |period|
              sum = (sum_hours(select_hours(hours_for_value, report.columns, period.to_s))).to_f;

                graph_data[:data] << {:month => period, :count=>sum} if level == 0              
           end
              graph_final_data << graph_data if level == 0
              graph_data = {} if level == 0

          if report.criteria.length > level+1
           # p value
           graph_final_level1_data = get_graph_level1_data(report, hours_for_value,graph_final_data.last, level+1)
           graph_final_data[graph_final_data.length-1] = graph_final_level1_data
          end
         
       end
        graph_final_data = [graph_final_data.to_json]
    end
  end

  def get_graph_level1_data(report,hours,graph_final_data,level)
     criterias=report.criteria
     criteria = criterias[level]
     level1_data = graph_final_data
    report.hours.collect {|h| h[criteria].to_s}.uniq.each do |value|
           hours_for_value = select_hours(hours, criteria, value)
           legend = h(format_criteria_value(report.available_criteria[criteria], value))
           legend = legend[0...17]+'...' if criteria == "issue" && legend != "" 

           report.periods.each do |period|
            sum = (sum_hours(select_hours(hours_for_value, report.columns, period.to_s))).to_f;
               level1_data[:data].each_with_index do |res,i|
                 if res[:month] == period
                  
                  sum = (sum.to_i <= 1)  ? "#{sprintf( "%0.02f", sum)}Hr" : "#{sprintf( "%0.02f", sum)}Hrs"
                    if res.has_key?(:result)
                       res[:result] << "#{legend}-#{sum}"
                    else
                       res[:result] = ["#{legend}-#{sum}"]
                    end
                    level1_data[:data][i] = res
                 end
               end
               level1_data
           end 
           level1_data = level1_data
       end
       level1_data
  end

  def report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours, level=0)
    decimal_separator = l(:general_csv_decimal_separator)
    hours.collect {|h| h[criteria[level]].to_s}.uniq.each do |value|
      hours_for_value = select_hours(hours, criteria[level], value)
      next if hours_for_value.empty?
      row = [''] * level
      row << Redmine::CodesetUtil.from_utf8(
                        format_criteria_value(available_criteria[criteria[level]], value).to_s,
                        l(:general_csv_encoding) )
      row += [''] * (criteria.length - level - 1)
      total = 0
      periods.each do |period|
        sum = sum_hours(select_hours(hours_for_value, columns, period.to_s))        
        total += sum.to_f
        row << (sum.to_f > 0 ? ("%.2f" % sum).gsub('.',decimal_separator) : '')
      end
      row << ("%.2f" % total).gsub('.',decimal_separator)
      csv << row
      if criteria.length > level + 1
        report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours_for_value, level + 1)
      end
    end
  end

  def find_project_managers(project)
    @clients = []
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
