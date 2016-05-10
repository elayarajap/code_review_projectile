class ReportApiController  < ApplicationController
  skip_filter(*_process_action_callbacks.map(&:filter))#, :only => :management_api_report

  def management_api_report
    render :json => ConsolidatedReport.consolidated_json(params[:from_date],params[:to_date],params[:group_id],params[:excel_view])
  end

  def fetch_all_groups
  	render :json => ConsolidatedReport.all_groups
  end
end