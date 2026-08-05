module Adapters
  # GoHighLevel (GHL): appointments booked and estimated revenue for the report
  # month. Per SOW #9, whether a GHL connection exists for a client is itself
  # the "online scheduler enrollment" signal — the generator only invokes this
  # adapter when a ClientServiceLink for "ghl" exists; absence means
  # `ghl_data_status: "not_connected"` without ever calling the API.
  #
  # Bearer token: a client-level ClientServiceLink#override_credentials
  # access_token (a raw Private Integration Token, the pre-OAuth per-client
  # workaround) if one is on record, else a location-scoped token minted
  # on demand from the agency-wide OAuth grant via GhlOauthClient — never the
  # agency connection's own access_token directly, which is scoped for
  # minting location tokens, not for calling these two endpoints itself.
  # external_id: the GHL location ID for this client.
  #
  # Uses GHL's v2 API (services.leadconnectorhq.com), which requires the
  # `Version` header pinned to a specific API release date.
  class GhlAdapter < Base
    SERVICE = "ghl"
    BASE_URL = "https://services.leadconnectorhq.com"
    API_VERSION = "2021-07-28"

    private

    def perform
      return Result.failure("ghl: no location id configured for this client") if external_id.blank?

      appointments = fetch_appointments_count
      revenue = fetch_won_opportunities_revenue

      Result.success(
        appointments_booked: appointments,
        estimated_revenue: revenue,
        ghl_data_status: "connected"
      )
    end

    def fetch_appointments_count
      response = api_connection.get("/calendars/events", {
        locationId: external_id,
        startTime: month_range.begin.beginning_of_day.to_i * 1000,
        endTime: month_range.end.end_of_day.to_i * 1000
      })

      JSON.parse(response.body).fetch("events", []).size
    end

    def fetch_won_opportunities_revenue
      response = api_connection.get("/opportunities/search", {
        location_id: external_id,
        status: "won",
        date_updated_start: month_range.begin.iso8601,
        date_updated_end: month_range.end.iso8601
      })

      JSON.parse(response.body).fetch("opportunities", []).sum { |o| o["monetaryValue"].to_f }
    end

    def api_connection
      connection(BASE_URL, headers: {
        "Authorization" => "Bearer #{bearer_token}",
        "Version" => API_VERSION
      })
    end

    # Memoized per #perform (both calls below share one token) rather than
    # cached across requests — mirrors GoogleAnalyticsAdapter#access_token.
    def bearer_token
      @bearer_token ||= client_service_link&.credentials&.dig("access_token") || GhlOauthClient.new.location_access_token!(location_id: external_id)
    end
  end
end
