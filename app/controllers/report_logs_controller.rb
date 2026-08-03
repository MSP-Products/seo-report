class ReportLogsController < ApplicationController
  def index
    @month = MonthlyReport.parse_month_param(params[:month])
    @months = MonthlyReport.distinct.order(report_month: :desc).pluck(:report_month)
    @status = params[:status].presence_in(MonthlyReport::EFFECTIVE_STATUSES)

    all_reports = MonthlyReport.for_report_log(month: @month).to_a
    @status_counts = all_reports.group_by(&:effective_status).transform_values(&:count)
    @reports = @status ? all_reports.select { |report| report.effective_status == @status } : all_reports
  end
end
