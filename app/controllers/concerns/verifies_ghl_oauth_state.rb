# frozen_string_literal: true

# CSRF state handling for the GHL OAuth redirect flow (Connections::GhlOauthController)
# — a GET-based external redirect where the standard authenticity-token
# protection doesn't apply, so the state param does that job instead.
module VerifiesGhlOauthState
  extend ActiveSupport::Concern

  included do
    before_action :require_editor!, only: [ :authorize, :callback ]
    before_action :set_oauth_state, only: :authorize
    before_action :verify_oauth_state!, only: :callback

    rescue_from GhlOauthClient::AuthorizationError do |e|
      redirect_to edit_connection_path(:ghl), alert: "GoHighLevel connection failed: #{e.message}"
    end
  end

  private

  # redirect_uri is computed once here (from whatever host the admin is
  # actually browsing on — localhost, a dev tunnel, or production) and reused
  # unchanged in the callback, since GHL requires the value sent at exchange
  # time to match the one sent at authorize time exactly.
  def set_oauth_state
    session[:ghl_oauth_state] = SecureRandom.hex(16)
    session[:ghl_oauth_redirect_uri] = "#{request.base_url}#{connections_ghl_callback_path}"
  end

  def verify_oauth_state!
    return if ActiveSupport::SecurityUtils.secure_compare(session.delete(:ghl_oauth_state).to_s, params[:state].to_s)

    raise GhlOauthClient::AuthorizationError, "state mismatch"
  end
end
