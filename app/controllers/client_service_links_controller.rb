class ClientServiceLinksController < ApplicationController
  before_action :require_editor!, only: [ :edit, :update ]

  def index
    @client = Client.kept.find(params[:client_id])
    @client_service_links = @client.all_service_links
  end

  def edit
    @client = Client.kept.find(params[:client_id])
    return redirect_to client_data_sources_path(@client), alert: "Unknown service." unless Service::KEYS.include?(params[:service])

    @link = @client.client_service_links.find_or_initialize_by(service: params[:service])
  end

  def update
    @client = Client.kept.find(params[:client_id])
    return redirect_to client_data_sources_path(@client), alert: "Unknown service." unless Service::KEYS.include?(params[:service])

    @link = @client.client_service_links.find_or_initialize_by(service: params[:service])
    @link.external_id = params.require(:client_service_link).permit(:external_id)[:external_id]

    if @link.save
      redirect_to client_data_sources_path(@client), notice: "#{AgencyConnection::DISPLAY.fetch(@link.service)[:name]} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
