class ReportsController < ApplicationController
  layout "report"

  skip_before_action :authenticate_admin!
  rescue_from ActiveRecord::RecordNotFound, with: :report_not_found

  def show
    monthly_report = MonthlyReport.includes(
      :client,
      :report_highlight,
      :report_traffic,
      :report_citation,
      :report_gbp_summary,
      :gbp_posts,
      :gbp_reviews,
      :gbp_photos,
      :report_pages_published,
      report_ai_visibility: :report_ai_platform_scores,
      report_keyword_rankings: :keyword
    ).find_by!(access_token: params[:access_token])

    @report = ReportPresenter.new(monthly_report)
  end

  private

  def report_not_found
    render "reports/not_found", status: :not_found
  end
end
