class ClientOffboardingsController < ApplicationController
  before_action :require_editor!

  def create
    client = Client.kept.find(params[:client_id])
    client.update!(onboarding_status: "offboarded")
    redirect_to client_path(client), notice: "#{client.name} offboarded."
  end
end
