class ClientsController < ApplicationController
  include FindsClient

  before_action(only: %i[ new create ]) { require_permission!(:clients_create) }
  before_action(only: %i[ edit update restore ]) { require_permission!(:clients_edit) }
  before_action(only: [ :destroy ]) { require_permission!(@client.discarded? ? :clients_delete : :clients_edit) }

  def index
    @status = params[:status].presence_in([ "all", *Client.onboarding_statuses.keys ]) || "active"
    # Show all records (active + pending + offboarded) or filtered by status
    clients = case @status
    when "offboarded"
      Client.discarded.search(params[:q]).by_status(@status)
    when "all"
      # Combine kept (active, pending) with discarded (offboarded)
      Client.unscoped.search(params[:q]).includes(:monthly_reports, :client_service_links).order(:name)
    else
      Client.kept.search(params[:q]).by_status(@status)
    end
    clients = clients.includes(:monthly_reports, :client_service_links).order(:name) unless @status == "all"
    @status_counts = Client.status_counts(params[:q])
    @query = PaginatedClientsQuery.new(clients, page: params[:page])
  end

  def show
    @tab = params[:tab].presence_in(%w[overview reports keywords sources]) || "overview"
  end

  def new
    @client = Client.new(name: params[:hubspot_name])
    @client.client_service_links.build(service: "hubspot", external_id: params[:hubspot_company_id]) if params[:hubspot_company_id].present?
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
    client_name = @client.name
    if @client.discarded?
      # Permanently delete if already offboarded
      @client.destroy!
      redirect_to clients_path, notice: "#{client_name} permanently deleted."
    else
      # Soft-delete (offboard) if active
      @client.update(onboarding_status: :offboarded)
      @client.discard
      redirect_to clients_path, notice: "#{client_name} offboarded."
    end
  end

  # onboarding_status has to come back off "offboarded" too, or the practice is
  # kept-but-offboarded: it matches no status tab (the Offboarded tab lists
  # discarded rows only) and disappears from the list. "pending" is the honest
  # value — only a successful HubSpot sync may promote a practice to active.
  def restore
    @client.update!(onboarding_status: :pending)
    @client.undiscard
    redirect_to client_path(@client), notice: "#{@client.name} restored. Note: HubSpot will sync in ~1 hour and may offboard again if still marked that way there."
  end
end
