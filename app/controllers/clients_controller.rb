class ClientsController < ApplicationController
  include FindsClient

  before_action :require_editor!, only: [ :new, :create, :edit, :update, :destroy ]

  def index
    @status = params[:status].presence_in(Client.onboarding_statuses.keys)
    clients = Client.kept.search(params[:q]).by_status(@status)
      .includes(:monthly_reports, :client_service_links).order(:name)
    @query = PaginatedClientsQuery.new(clients, page: params[:page])
  end

  def show
    @tab = params[:tab].presence_in(%w[overview reports keywords sources]) || "overview"
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)

    if @client.save
      redirect_to client_path(@client), notice: "#{@client.name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to client_path(@client), notice: "#{@client.name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.discard
    redirect_to clients_path, notice: "#{@client.name} offboarded."
  end
end
