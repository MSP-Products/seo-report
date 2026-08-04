class ClientsController < ApplicationController
  before_action :require_editor!, only: [ :edit, :update ]

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
    @client = Client.new
  end

  def create
    attrs = params.require(:client).permit(:name, :website_url, :phone, :address, :sitemap_url)
    service_links = params.fetch(:service_links, {}).permit(*Service::KEYS)
    @client = ClientCreator.new(attrs: attrs, service_external_ids: service_links).call

    if @client.persisted?
      redirect_to client_path(@client), notice: "#{@client.name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @client = Client.kept.find(params[:id])
  end

  def update
    client = Client.kept.find(params[:id])
    attrs = params.require(:client).permit(:name, :website_url, :phone, :address, :sitemap_url)
    service_links = params.fetch(:service_links, {}).permit(*Service::KEYS)
    @client = ClientUpdater.new(client: client, attrs: attrs, service_external_ids: service_links).call

    if @client.errors.empty?
      redirect_to client_path(@client), notice: "#{@client.name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
