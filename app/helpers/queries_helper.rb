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

module QueriesHelper
  def filters_options_for_select(query)
    options_for_select(filters_options(query))
  end

  def filters_options(query)
    options = [[]]
    options += query.available_filters.map do |field, field_options|
      [field_options[:name], field]
    end
  end

  def available_block_columns_tags(query)
    tags = ''.html_safe
    query.available_block_columns.each do |column|
      tags << content_tag('label', check_box_tag('c[]', column.name.to_s, query.has_column?(column)) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def query_available_inline_columns_options(query)
    (query.available_inline_columns - query.columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def query_selected_inline_columns_options(query)
    (query.inline_columns & query.available_inline_columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def render_query_columns_selection(query, options={})
    tag_name = (options[:name] || 'c') + '[]'
    render :partial => 'queries/columns', :locals => {:query => query, :tag_name => tag_name}
  end

  def column_header(column)
    column.sortable ? sort_header_tag(column.name.to_s, :caption => column.caption,
                                                        :default_order => column.default_order) :
                      content_tag('th', h(column.caption))
  end

  def column_content(column, issue)
    value = column.value(issue)
    if value.is_a?(Array)
      value.collect {|v| column_value(column, issue, v)}.compact.join(', ').html_safe
    else
      column_value(column, issue, value)
    end
  end
  
  def column_value(column, issue, value)
    case value.class.name
    when 'String'
      if column.name == :subject
        link_to(h(value), :controller => 'issues', :action => 'show', :id => issue)
      elsif column.name == :description
        issue.description? ? content_tag('div', textilizable(issue, :description), :class => "wiki") : ''
      else
        h(value)
      end
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Fixnum'
      if column.name == :id
        link_to value, issue_path(issue)
      elsif column.name == :done_ratio
        progress_bar(value, :width => '80px')
      else
        value.to_s
      end
    when 'Float'
      sprintf "%.2f", value
    when 'User'
      link_to_user value
    when 'Project'
      link_to_project value
    when 'Version'
      link_to(h(value), :controller => 'versions', :action => 'show', :id => value)
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    when 'Issue'
      value.visible? ? link_to_issue(value) : "##{value.id}"
    when 'IssueRelation'
      other = value.other_issue(issue)
      content_tag('span',
        (l(value.label_for(issue)) + " " + link_to_issue(other, :subject => false, :tracker => false)).html_safe,
        :class => value.css_classes_for(issue))
    else
      h(value)
    end
  end

  def csv_content(column, issue)
    value = column.value(issue)
    if value.is_a?(Array)
      value.collect {|v| csv_value(column, issue, v)}.compact.join(', ')
    else
      csv_value(column, issue, value)
    end
  end

  def csv_value(column, issue, value)
    case value.class.name
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Float'
      sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
    when 'IssueRelation'
      other = value.other_issue(issue)
      l(value.label_for(issue)) + " ##{other.id}"
    else
      value.to_s
    end
  end

  def query_to_csv(items, query, options={})
    encoding = l(:general_csv_encoding)
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end

    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
      # csv lines
      items.each do |item|
        csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(csv_content(c, item), encoding) }
      end
    end
    export
  end

  def query_to_csv_timelog(items, query, options={})
    encoding = l(:general_csv_encoding)
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns_timelog)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      columns.collect {|c| p c.caption.to_s }
      csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
      # csv lines
      items.each do |item|
        csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(csv_content(c, item), encoding) }
      end
    end
    export
  end

  # Retrieve query from session or build a new query

  def retrieve_query_org
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = IssueQuery.find(params[:query_id], :conditions => cond)
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = IssueQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = IssueQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      @query.project = @project
    end
  end


  def retrieve_query

    trackertype = params["tid"]
    statustype = params["status_id"]
    currentime = Time.now.strftime("%Y-%m-%d")
    fixedid=""

    params.delete(:set_filter) if params[:page]
    hash = params
    hashcount = hash.count
    if params["sprint"]
      fixedid = "#{params["sprint"]}"
      hash["set_filter"] = "1" 
    else
      fixedid = "#{@fixedid.first.id}" unless @fixedid.empty?
    end
    #hash["utf8"] = "✓"
    #hash["set_filter"] = "1"
    #if hashcount != 9        
    if hashcount != 9 || params[:action] == "create"   #Default Hash values     
        hash["f"] = ["status_id", "tracker_id", "fixed_version_id", "priority_id","author_id","assigned_to_id",""]
        hash["op"] = {"status_id"=>"*", "tracker_id"=>"=", "fixed_version_id"=>"=","priority_id"=>"*","author_id"=>"*","assigned_to_id"=>"*"}
        hash["v"] = {"status_id"=>["#{@allowed_statuses.first.id}"] ,"tracker_id"=>[trackertype], "fixed_version_id"=>[fixedid],"priority_id"=>["*"],"author_id"=>["*"],"assigned_to_id"=>["0"]}
        
        #Below set of code is to display severity
        if trackertype.to_s == "1" && params[:tid]== "1" #Its for Bug
          hash["f"][6] = "cf_6"
          hash["f"][7] = "" 
          hash["op"]["cf_6"]="!"
          hash["v"]["cf_6"]=["10"]
        end
    end
    #default operator for others
    hash["v"].each do |key, value|
      if value==["*"]
        hash["op"]["#{key}"]="*" #Value has to change
      end
    end
    #Set default operator for severity   
    if params[:v][:cf_6] && params[:v][:cf_6][0]=="10"
      params[:op][:cf_6] ="!"     
    end
    #Set default operator for assignee 
    if params[:v][:assigned_to_id] && params[:v][:assigned_to_id][0]=="0"
      params[:op][:assigned_to_id] ="!"     
    end
    if params[:v][:subject] && params[:v][:subject][0].blank?
      hash["f"].delete("subject")
      hash["op"].tap {|op| op.delete(:subject)}      
      hash["v"].tap {|v| v.delete(:subject)}
    end
    hash["c"] = ["tracker", "status", "priority", "subject", "assigned_to", "updated_on"]
    hash["group_by"] = ""
    #Check the tracker id and get respective filter query
    params[:tid] == "2" ? retrieve_todo_query : retrieve_issue_query
    
  end

  def retrieve_issue_query
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = IssueQuery.find(params[:query_id], :conditions => cond)
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = IssueQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = IssueQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      @query.project = @project
    end
  end

  def retrieve_todo_query
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = IssueQuery.find(params[:query_id], :conditions => cond)
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:todoquery] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:todoquery].nil? || session[:todoquery][:project_id] != (@project ? @project.id : nil)  
      # Give it a name, required to be valid
      @query = IssueQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:todoquery] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = IssueQuery.find_by_id(session[:todoquery][:id]) if session[:todoquery][:id]
      @query ||= IssueQuery.new(:name => "_", :filters => session[:todoquery][:filters], :group_by => session[:todoquery][:group_by], :column_names => session[:todoquery][:column_names])
      @query.project = @project
    end
  end

  def retrieve_query_from_session
    if session[:query]
      if session[:query][:id]
        @query = IssueQuery.find_by_id(session[:query][:id])
        return unless @query
      else
        @query = IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      end
      if session[:query].has_key?(:project_id)
        @query.project_id = session[:query][:project_id]
      else
        @query.project = @project
      end
      @query
    end
  end
end
