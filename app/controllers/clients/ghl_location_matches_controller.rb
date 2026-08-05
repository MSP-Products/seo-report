# frozen_string_literal: true

class Clients::GhlLocationMatchesController < ApplicationController
  include FindsClient

  before_action :require_editor!
  before_action :set_client

  rescue_from Faraday::Error, GhlOauthClient::NotConnectedError do
    flash.now[:alert] = "Couldn't reach GoHighLevel to check for a match — try again in a moment."
    render "clients/edit"
  end

  def create
    @ghl_suggested_match = GhlLocationMatcher.new(@client).call || false
    render "clients/edit"
  end
end
