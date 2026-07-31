module Adapters
  # Yext covers three distinct parts of the report (SOW #4): Citation &
  # Directory Performance (Analytics API), AI Visibility (the "Scout" product),
  # and Google Business Profile activity — GBP is listed in the SOW as
  # "Yext or GBP directly — TBD", and since GBP isn't one of the four named
  # APIs for this pass, it's sourced through Yext here.
  #
  # Credentials shape: {"api_key" => "..."}.
  # external_id: the Yext entity/location ID for this client.
  #
  # Citations and AI Visibility below are verified against a real account's
  # Analytics Reports API (POST /analytics/reports) — metrics, dimensions, and
  # response shape confirmed empirically, not just from docs. Two things this
  # confirmed that don't match assumptions baked into the schema/report page:
  #   - Sentiment metrics are fractions (0-1), not 0-100 percentages, and there
  #     is no separate "positive sentiment" metric — it's derived as
  #     1 - negative - neutral.
  #   - AI_MODEL values returned by this account (e.g. "GEMINI", "PERPLEXITY")
  #     don't match ReportAiPlatformScore's old fixed enum, which is why that
  #     enum was removed in favor of storing whatever Yext returns directly.
  #   - Yext has no distinct metrics for "driving directions" vs "website
  #     clicks" — only a combined total (TOTAL_LISTINGS_ACTIONS). Those two
  #     fields are left nil; the report page omits that breakdown when blank.
  #   - SCOUT_GOOGLE_RANK's scale is unconfirmed (observed 0.0 for an account
  #     with no ranked keywords) — flagged here in case it turns out to need
  #     different handling once more accounts/data are available.
  #
  # LOWER CONFIDENCE: fetch_gbp_activity is still an unverified placeholder
  # endpoint — confirm against a real response before relying on it.
  class YextAdapter < Base
    SERVICE = "yext"
    BASE_URL = "https://api.yextapis.com"
    API_VERSION = "20240101"
    REPORTS_PATH = "/v2/accounts/me/analytics/reports".freeze

    AI_VISIBILITY_METRICS = {
      overall_score: "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE",
      google_rank: "SCOUT_GOOGLE_RANK",
      ai_rank: "SCOUT_AI_RANK_SCORE",
      sentiment_negative_pct: "SCOUT_NEGATIVE_SENTIMENT_SCORE",
      sentiment_neutral_pct: "SCOUT_NEUTRAL_SENTIMENT_SCORE"
    }.freeze

    private

    def perform
      citations = fetch_citations
      return Result.failure("yext: #{citations[:error]}") unless citations[:ok]

      Result.success(
        citations: citations[:data],
        ai_visibility: fetch_ai_visibility,
        gbp: fetch_gbp_activity
      )
    end

    def fetch_citations
      impressions = run_report(
        metrics: [ "TOTAL_LISTINGS_IMPRESSIONS" ], dimensions: [ "LOCATION_IDS" ],
        filters: { locationIds: [ external_id ] }
      )
      engagements = run_report(
        metrics: [ "TOTAL_LISTINGS_ACTIONS" ], dimensions: [ "ENTITY_IDS" ],
        filters: { entityIds: [ external_id ] }
      )

      {
        ok: true,
        data: {
          total_impressions: metric_value(impressions, %w[LOCATION_IDS]),
          total_engagements: metric_value(engagements, %w[ENTITY_IDS]),
          # Not available: Yext only exposes a combined actions total, no
          # per-type (driving directions vs. website clicks) breakdown.
          driving_directions_count: nil,
          website_clicks_count: nil
        }
      }
    rescue Faraday::Error => e
      { ok: false, error: e.message }
    end

    def fetch_ai_visibility
      row = run_report(
        metrics: AI_VISIBILITY_METRICS.values, dimensions: [ "ENTITY_IDS" ],
        filters: { entityIds: [ external_id ] }
      )
      return nil if row.nil?

      negative = (row[AI_VISIBILITY_METRICS[:sentiment_negative_pct]].to_f * 100).round
      neutral = (row[AI_VISIBILITY_METRICS[:sentiment_neutral_pct]].to_f * 100).round

      {
        overall_score: row[AI_VISIBILITY_METRICS[:overall_score]],
        google_rank: row[AI_VISIBILITY_METRICS[:google_rank]],
        ai_rank: row[AI_VISIBILITY_METRICS[:ai_rank]],
        sentiment_negative_pct: negative,
        sentiment_neutral_pct: neutral,
        sentiment_positive_pct: [ 100 - negative - neutral, 0 ].max,
        # Not available: no citation-source-breakdown metric found in Yext's
        # analytics catalog for this account.
        citation_own_site_pct: nil,
        citation_listings_pct: nil,
        citation_reputation_pct: nil,
        citation_third_party_pct: nil,
        platform_scores: fetch_platform_scores
      }
    rescue Faraday::Error
      nil
    end

    def fetch_platform_scores
      rows = run_report_rows(
        metrics: [ AI_VISIBILITY_METRICS[:ai_rank] ], dimensions: [ "AI_MODEL", "ENTITY_IDS" ],
        filters: { entityIds: [ external_id ] }
      )

      rows.to_a.filter_map do |row|
        platform = row["AI_MODEL"]
        next if platform.blank?

        [ platform.downcase, metric_value(row, %w[AI_MODEL ENTITY_IDS]) ]
      end.to_h
    rescue Faraday::Error
      {}
    end

    def fetch_gbp_activity
      response = api_connection.get("/v2/accounts/me/locations/#{external_id}/gbp-activity", {
        startDate: month_range.begin.iso8601,
        endDate: month_range.end.iso8601
      })
      body = JSON.parse(response.body).fetch("response", {})

      {
        # Lifetime aggregates across the whole GBP listing — distinct from
        # `reviews` below, which is just this month's new reviews.
        total_reviews: body["totalReviewCount"],
        average_rating: body["averageRating"],
        posts: Array(body["posts"]).map { |p| { title: p["title"], description: p["description"], published_at: p["publishedAt"] } },
        reviews: Array(body["reviews"]).map { |r|
          {
            external_id: r["id"], author_name: r["authorName"], rating: r["rating"],
            body: r["comment"], posted_at: r["postedAt"]
          }
        },
        photos: Array(body["photos"]).map { |p| { image_url: p["url"], caption: p["caption"] } }
      }
    rescue Faraday::Error
      nil
    end

    # Runs an analytics report and returns the single data row (a Hash), or
    # nil if the report came back empty.
    def run_report(metrics:, dimensions:, filters:)
      run_report_rows(metrics: metrics, dimensions: dimensions, filters: filters).first
    end

    def run_report_rows(metrics:, dimensions:, filters:)
      response = api_connection.post(REPORTS_PATH) do |req|
        req.body = {
          metrics: metrics,
          dimensions: dimensions,
          filters: filters.merge(startDate: month_range.begin.iso8601, endDate: month_range.end.iso8601)
        }.to_json
      end

      JSON.parse(response.body).dig("response", "data")
    end

    # Yext sometimes keys a report row by the metric's raw ID and sometimes by
    # its human-friendly display name (observed both, even within the same
    # account) — rather than guess the label, take whichever value remains
    # after excluding the known dimension keys.
    def metric_value(row, dimension_keys)
      return nil if row.nil?

      row.reject { |key, _| dimension_keys.include?(key) }.values.first
    end

    def api_connection
      connection(BASE_URL, headers: { "Content-Type" => "application/json" })
        .tap { |conn| conn.params["api_key"] = credentials["api_key"]; conn.params["v"] = API_VERSION }
    end
  end
end
