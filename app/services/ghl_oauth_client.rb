# frozen_string_literal: true

# Owns the whole GoHighLevel (GHL) agency-level OAuth lifecycle against the
# one "ghl" AgencyConnection row: the one-time authorization-code exchange,
# transparent refresh-token rotation, and minting a short-lived per-location
# token from the stored agency token (so GhlAdapter can keep making its two
# report-data calls per client without a credential of its own).
#
# App identity (client_id/client_secret) lives in Rails credentials/ENV, not
# here — it's the Marketplace app's own registration, shared across every
# deploy, not part of any one agency's grant. See AgencyConnection for why
# access_token/refresh_token/expires_at instead stay in its encrypted JSON
# blob (this agency's live, volatile grant).
#
# LOCATION_TOKEN_PATH and SCOPES are confirmed live against a real GHL
# Marketplace app and account — see docs/features/integration-ghl.md.
class GhlOauthClient
  class AuthorizationError < StandardError; end

  # Raised by the report-generation path (#location_access_token!), never by
  # the human-facing OAuth callback — a Faraday::Error subclass so it flows
  # through Adapters::Base#call's existing `rescue Faraday::Error` unchanged,
  # into the standard Result.failure/logged/re-raised path, instead of
  # escaping uncaught the way a plain StandardError would.
  class NotConnectedError < Faraday::Error; end

  BASE_URL = "https://services.leadconnectorhq.com"
  AUTHORIZE_URL = "https://marketplace.gohighlevel.com/oauth/chooselocation"
  TOKEN_PATH = "/oauth/token"
  LOCATION_TOKEN_PATH = "/oauth/locationToken" # unverified — see class comment
  API_VERSION = "2021-07-28"
  # Matches the app's Target User: Sub-Account (not Agency) configuration —
  # only Sub-Account-scoped resources are grantable. oauth.write/oauth.readonly
  # are required for #location_access_token! to mint per-location tokens.
  # calendars.readonly (list a location's calendars) is separate from
  # calendars/events.readonly (list events on one of them) — GHL's
  # /calendars/events requires filtering by a specific calendarId/userId/
  # groupId, so listing calendars first is a real prerequisite, not optional.
  # locations.readonly is not used by GhlAdapter yet — added ahead of a
  # planned domain-based auto-match between GHL locations and Client records.
  SCOPES = %w[calendars.readonly calendars/events.readonly opportunities.readonly oauth.write oauth.readonly locations.readonly].freeze
  # Wider than the strict minimum on purpose: RefreshGhlTokenJob runs every 4
  # hours (config/recurring.yml), and this buffer must exceed that gap so the
  # job always catches a token before it actually expires, rather than
  # leaving that entirely to the lazy refresh in #location_access_token!. Also
  # means a real refresh (and the last_verified_at bump that comes with it)
  # happens roughly every 12 hours rather than only once near the ~24h token's
  # expiry, so last_verified_at stays a meaningful "still healthy" signal.
  EXPIRY_BUFFER = 12.hours

  def initialize
    @connection = AgencyConnection.find_or_initialize_by(service: "ghl")
  end

  def authorize_url(redirect_uri:, state:)
    # In development with stub mode on, skip GHL's real OAuth flow and return the
    # callback directly with a fake code — the whole OAuth exchange happens instantly
    # without leaving the browser, and all subsequent GHL API calls hit WebMock stubs.
    if stub_enabled?
      return "#{redirect_uri}?code=stub-code-#{SecureRandom.hex(16)}&state=#{state}"
    end

    query = URI.encode_www_form(
      response_type: "code", client_id: client_id, redirect_uri: redirect_uri,
      scope: SCOPES.join(" "), state: state, user_type: "Company"
    )

    "#{AUTHORIZE_URL}?#{query}"
  end

  # Called by Connections::GhlOauthController#callback. Human-facing: raises
  # AuthorizationError with a short, generic message on any failure — never
  # let GHL's raw response body reach an admin's flash.
  def exchange_code!(code:, redirect_uri:)
    request_token!(grant_type: "authorization_code", code: code, redirect_uri: redirect_uri)
  rescue Faraday::Error => e
    Rails.logger.warn("ghl_oauth: code exchange failed (#{e.response&.dig(:status)})")
    raise AuthorizationError, "could not complete authorization"
  end

  # Called by GhlAdapter. Report-generation-facing: lets Faraday::Error
  # propagate UNWRAPPED — Adapters::Base#call already rescues it, so the
  # existing failed/logged/re-raised path stays untouched.
  def location_access_token!(location_id:)
    refresh! if token_stale?

    mint_location_token!(location_id: location_id)
  end

  # Called by GhlLocationMatcher — some GHL endpoints (e.g. /locations/search)
  # are agency-scoped and take the raw agency token directly, not a minted
  # per-location one.
  def agency_access_token!
    refresh! if token_stale?

    @connection.credentials["access_token"]
  end

  # Called by RefreshGhlTokenJob's every-4-hours schedule to keep the agency token
  # from ever going stale between monthly report runs. A no-op, not an error,
  # when there's no connection yet — the job shouldn't fail an agency that
  # simply hasn't connected GHL at all.
  def refresh_if_stale!
    return unless connected?

    refresh! if token_stale?
  end

  private

  # On by default in development, because GHL's OAuth consent redirect can't
  # complete against localhost — without the stub, nothing downstream of
  # "Connect to GoHighLevel" is reachable locally at all. Opt out with
  # GHL_STUB=false to work against a real connection.
  #
  # Be aware when reading local results: a stubbed "match found" is
  # indistinguishable in the UI from a real one, so GHL behaviour verified
  # locally proves the code path, not the integration.
  # Kept in step with config/initializers/ghl_stub.rb's identical guard.
  def stub_enabled?
    Rails.env.development? && ENV["GHL_STUB"] != "false"
  end

  def connected?
    @connection.credentials["refresh_token"].present?
  end

  def client_id
    Rails.application.credentials.dig(:ghl, :client_id) || ENV["GHL_CLIENT_ID"]
  end

  def client_secret
    Rails.application.credentials.dig(:ghl, :client_secret) || ENV["GHL_CLIENT_SECRET"]
  end

  # GHL rotates the refresh_token on every use — the response's NEW
  # refresh_token must replace the old one, or the connection is bricked on
  # the very next refresh attempt.
  def refresh!
    refresh_token = @connection.credentials["refresh_token"]
    raise NotConnectedError, "ghl: not connected via OAuth yet" if refresh_token.blank?

    request_token!(grant_type: "refresh_token", refresh_token: refresh_token)
  rescue NotConnectedError
    raise
  rescue Faraday::Error
    @connection.update!(credential_status: "expired")
    raise
  end

  def token_stale?
    access_token = @connection.credentials["access_token"]
    return true if access_token.blank?

    expires_at = @connection.expires_at
    expires_at.blank? || expires_at <= Time.current + EXPIRY_BUFFER
  end

  def request_token!(**body)
    response = token_connection.post(TOKEN_PATH) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(body.merge(client_id: client_id, client_secret: client_secret, user_type: "Company"))
    end

    persist_tokens!(JSON.parse(response.body))
  end

  def persist_tokens!(payload)
    @connection.update!(
      encrypted_credentials: @connection.credentials.merge(
        "access_token" => payload.fetch("access_token"),
        "refresh_token" => payload.fetch("refresh_token"),
        "company_id" => payload["companyId"] || @connection.credentials["company_id"]
      ).to_json,
      expires_at: Time.current + payload.fetch("expires_in").seconds,
      credential_status: "active",
      last_verified_at: Time.current
    )
  end

  def mint_location_token!(location_id:)
    company_id = @connection.credentials["company_id"]
    raise NotConnectedError, "ghl: no company id on record — reauthorize" if company_id.blank?

    response = api_connection.post(LOCATION_TOKEN_PATH) do |req|
      req.headers["Authorization"] = "Bearer #{@connection.credentials['access_token']}"
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form(companyId: company_id, locationId: location_id)
    end

    JSON.parse(response.body).fetch("access_token")
  end

  def token_connection
    Adapters::ConnectionBuilder.build(BASE_URL)
  end

  def api_connection
    Adapters::ConnectionBuilder.build(BASE_URL, headers: { "Version" => API_VERSION })
  end
end
