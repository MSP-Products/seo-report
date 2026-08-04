class MonthlyReportsController < ApplicationController
  def index
    @client = Client.kept.find(params[:client_id])
    @reports = @client.monthly_reports.order(report_month: :desc)
  end
end
