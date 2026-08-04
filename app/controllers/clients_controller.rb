class ClientsController < ApplicationController
  def index
    @clients = ClientsQuery.new(search: params[:q], status: params[:status], page: params[:page]).call
  end

  def show
    @client = Client.kept.find(params[:id])
    @reports = @client.monthly_reports.order(report_month: :desc)
  end

  def new
  end

  def create
    redirect_to clients_path
  end
end
