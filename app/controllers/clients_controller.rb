class ClientsController < ApplicationController
  def index
    @clients = ClientsQuery.new(search: params[:q], status: params[:status], page: params[:page]).call
  end

  def show
    @client = Client.kept.find(params[:id])
    @reports = @client.monthly_reports.order(report_month: :desc)
    @latest_report = @client.latest_generated_report
    @latest_report_presenter = ReportPresenter.new(@latest_report) if @latest_report
    @current_cycle_report = @client.current_cycle_report
  end

  def new
  end

  def create
    redirect_to clients_path
  end
end
