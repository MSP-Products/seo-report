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

    # Lists the location's calendars rather than fetching a month of events —
    # the lightest already-used call that still 404s/errors on a bad or
    # revoked location ID, without pulling real report data.
    def check_connection
      return Result.failure("ghl: no location id configured for this client") if external_id.blank?

      fetch_calendar_ids
      Result.success
    end

    # GHL's /calendars/events has no "all events for this location" mode —
    # it requires filtering by one of calendarId/userId/groupId (confirmed
    # live: querying without one 422s with "Either of userId, calendarId or
    # groupId is required"). So this lists the location's calendars first,
    # then sums each one's event count for the month.
    def fetch_appointments_count
      fetch_calendar_ids.sum { |calendar_id| fetch_calendar_events_count(calendar_id) }
    end

    def fetch_calendar_ids
      response = api_connection.get("/calendars/", { locationId: external_id })

      JSON.parse(response.body).fetch("calendars", []).map { |calendar| calendar["id"] }
    end

    def fetch_calendar_events_count(calendar_id)
      response = api_connection.get("/calendars/events", {
        locationId: external_id,
        calendarId: calendar_id,
        startTime: month_range.begin.beginning_of_day.to_i * 1000,
        endTime: month_range.end.end_of_day.to_i * 1000
      })

      JSON.parse(response.body).fetch("events", []).size
    end

    # date/endDate (mm-dd-yyyy) are this endpoint's real date-filter params —
    # confirmed live after date_updated_start/date_updated_end (a reasonable-
    # looking guess) 422'd with "property ... should not exist". location_id
    # must stay snake_case: GHL's own docs page shows `locationId`, but the
    # live endpoint rejects that with "property locationId should not exist" —
    # the docs and the deployed API disagree here, and the deployed API wins.
    def fetch_won_opportunities_revenue
      response = api_connection.get("/opportunities/search", {
        location_id: external_id,
        status: "won",
        date: month_range.begin.strftime("%m-%d-%Y"),
        endDate: month_range.end.strftime("%m-%d-%Y")
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
