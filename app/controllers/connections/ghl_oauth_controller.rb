# frozen_string_literal: true

# GoHighLevel's agency-level OAuth redirect flow. Kept separate from
# ConnectionsController (a plain hand-typed credential form) since GHL is the
# one service whose credentials are OAuth-managed, not admin-typed.
class Connections::GhlOauthController < ApplicationController
  include VerifiesGhlOauthState

  def authorize
    redirect_to GhlOauthClient.new.authorize_url(redirect_uri: session[:ghl_oauth_redirect_uri], state: session[:ghl_oauth_state]),
      allow_other_host: true
  end

  def callback
    GhlOauthClient.new.exchange_code!(code: params[:code], redirect_uri: session.delete(:ghl_oauth_redirect_uri))
    redirect_to edit_connection_path(:ghl), notice: "Connected to GoHighLevel."
  end
end
