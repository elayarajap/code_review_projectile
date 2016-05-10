class SprintsController < ApplicationController

	before_filter :find_project

  def index
  	cond = @project.project_condition(Setting.display_subprojects_issues?)
  	if User.current.allowed_to?(:view_time_entries, @project)
      @total_hours = TimeEntry.visible.sum(:hours, :include => :project, :conditions => cond).to_f
    end
  	@sprints = Sprint.where(:project_id => @project.id)
  end
end
