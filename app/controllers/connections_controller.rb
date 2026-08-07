# Agency-wide API credentials for the external data-source adapters
# (HubSpot, GHL, Yext, SEMrush; Google Analytics has no live integration yet).
# See AgencyConnection for the per-service field/display metadata and the
# blank-means-unchanged credential update pattern used below.
class ConnectionsController < ApplicationController
  before_action(only: [ :edit, :update ]) { require_permission!(:connections_edit) }
  before_action :set_connection, only: [ :edit, :update ]
  before_action :ensure_configurable!, only: [ :edit, :update ]

  def index
    @connections = AgencyConnection.services.keys.map { |service| AgencyConnection.find_or_initialize_by(service: service) }
  end

  def edit
  end

  def update
    credentials = @connection.credentials
    submitted = params.require(:agency_connection).permit(*@connection.credential_fields.map { |f| f[:key] })

    @connection.credential_fields.each do |field|
      value = submitted[field[:key]]
      credentials[field[:key]] = value if value.present?
    end

    @connection.encrypted_credentials = credentials.to_json

    if @connection.save
      redirect_to connections_path, notice: "#{@connection.display_name} credentials updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_connection
    unless AgencyConnection.services.key?(params[:service])
      return redirect_to connections_path, alert: "Unknown service."
    end

    @connection = AgencyConnection.find_or_initialize_by(service: params[:service])
  end

  # set_connection halts the chain via redirect for an unknown service, so
  # @connection is always present by the time this runs.
  def ensure_configurable!
    return if @connection.credential_fields.present? || @connection.oauth_managed?

    redirect_to connections_path, alert: "#{@connection.display_name} isn't configurable yet."
  end
end
