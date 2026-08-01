module Adapters
  # Google Analytics 4 (GA4) Data API, for the report's traffic section
  # (SOW #4). Populates report_traffic's total_visits, organic/direct/
  # referral/paid visits, unique_visitors, and pages_per_visit.
  #
  # Credentials are agency-wide (see AgencyConnection) — one Google Cloud
  # service account reads any client's property once that client grants it
  # Viewer access, no per-client credentials needed:
  #   {"client_email" => "...", "private_key" => "-----BEGIN PRIVATE KEY-----\n..."}
  # external_id: the bare GA4 property ID (e.g. "384938446", not the
  # "properties/384938446" path form the API itself uses).
  #
  # Auth is Google's server-to-server JWT Bearer flow (RFC 7523) — no OAuth
  # consent screen or per-client authorization needed, unlike GHL.
  #
  # Two separate runReport calls, not one: GA4's per-channel breakdown can't
  # be safely summed into sitewide totals (a user who visits via both organic
  # and direct in the same month would be double-counted in unique_visitors),
  # so totals come from a dimension-less report and the organic/direct/
  # referral/paid split comes from a second, sessions-only report grouped by
  # channel. Verified live against a real property; channels outside the four
  # tracked here (Organic Social, Email, etc.) still count toward total_visits,
  # just aren't broken out into their own column.
  class GoogleAnalyticsAdapter < Base
    SERVICE = "google_analytics"
    BASE_URL = "https://analyticsdata.googleapis.com"
    TOKEN_URL = "https://oauth2.googleapis.com"
    SCOPE = "https://www.googleapis.com/auth/analytics.readonly"
    PAID_CHANNELS = [ "Paid Search", "Paid Social", "Paid Video", "Paid Shopping", "Paid Other" ].freeze

    private

    def perform
      return Result.failure("google_analytics: no GA4 property configured for this client") if external_id.blank?

      overview = fetch_overview
      breakdown = fetch_channel_breakdown

      Result.success(
        total_visits: overview[:sessions],
        unique_visitors: overview[:total_users],
        pages_per_visit: overview[:pages_per_session],
        organic_visits: breakdown["Organic Search"],
        direct_visits: breakdown["Direct"],
        referral_visits: breakdown["Referral"],
        paid_visits: PAID_CHANNELS.sum { |channel| breakdown[channel].to_i }
      )
    end

    def fetch_overview
      row = run_report(metrics: %w[sessions totalUsers screenPageViewsPerSession]).dig("rows", 0)
      values = row&.fetch("metricValues", [])

      {
        sessions: values&.dig(0, "value")&.to_i,
        total_users: values&.dig(1, "value")&.to_i,
        pages_per_session: values&.dig(2, "value")&.to_f
      }
    end

    def fetch_channel_breakdown
      rows = run_report(metrics: %w[sessions], dimensions: %w[sessionDefaultChannelGroup]).fetch("rows", [])

      rows.each_with_object({}) do |row, memo|
        channel = row.dig("dimensionValues", 0, "value")
        sessions = row.dig("metricValues", 0, "value")
        memo[channel] = sessions.to_i if channel.present?
      end
    end

    def run_report(metrics:, dimensions: [])
      response = data_connection.post("/v1beta/properties/#{external_id}:runReport") do |req|
        req.body = {
          metrics: metrics.map { |name| { name: name } },
          dimensions: dimensions.map { |name| { name: name } },
          dateRanges: [ { startDate: month_range.begin.iso8601, endDate: month_range.end.iso8601 } ]
        }.to_json
      end

      JSON.parse(response.body)
    end

    def data_connection
      connection(BASE_URL, headers: {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{access_token}"
      })
    end

    # Memoized per #perform (both runReport calls share one token) rather than
    # cached across requests — tokens are valid an hour, but minting fresh
    # each report run avoids stale-token bugs for negligible extra cost.
    def access_token
      @access_token ||= mint_access_token
    end

    def mint_access_token
      now = Time.current.to_i
      claims = {
        iss: credentials["client_email"], scope: SCOPE, aud: "#{TOKEN_URL}/token",
        exp: now + 3600, iat: now
      }
      jwt = sign_jwt(claims)

      response = connection(TOKEN_URL).post("/token") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt
        )
      end

      JSON.parse(response.body).fetch("access_token")
    end

    def sign_jwt(claims)
      header = { alg: "RS256", typ: "JWT" }
      signing_input = "#{base64url(header.to_json)}.#{base64url(claims.to_json)}"
      signature = private_key.sign(OpenSSL::Digest.new("SHA256"), signing_input)

      "#{signing_input}.#{base64url(signature)}"
    end

    # Service account keys are valid JSON, so private_key already contains
    # real newlines once parsed — the gsub only guards against a key that was
    # manually re-pasted into an ENV var or admin form with literal "\n"s.
    def private_key
      OpenSSL::PKey::RSA.new(credentials["private_key"].to_s.gsub('\n', "\n"))
    end

    def base64url(data)
      Base64.urlsafe_encode64(data, padding: false)
    end
  end
end
