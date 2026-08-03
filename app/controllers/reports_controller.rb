class ReportsController < ApplicationController
  layout "report"

  skip_before_action :authenticate_admin!

  rescue_from ActiveRecord::RecordNotFound do
    render "reports/not_found", status: :not_found
  end

  def show
    monthly_report = MonthlyReport.for_public_view.find_by!(access_token: params[:access_token])
    @report = ReportPresenter.new(monthly_report, keyword_page: params[:keyword_page])
  end
end
