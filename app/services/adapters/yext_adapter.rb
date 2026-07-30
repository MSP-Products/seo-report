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
  # LOWER CONFIDENCE: Scout is a newer Yext product with thin public API docs
  # at the time this was written. `fetch_ai_visibility`'s endpoint/response
  # shape is a best-effort placeholder — confirm against Yext's actual Scout
  # API reference once available and adjust the mapping in that one method.
  class YextAdapter < Base
    SERVICE = "yext"
    BASE_URL = "https://api.yextapis.com"
    API_VERSION = "20240101"

    PLATFORM_KEYS = %w[chatgpt google_ai_overview ai_mode gemini].freeze

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
      response = api_connection.get("/v2/accounts/me/analytics/listings", {
        locationId: external_id,
        startDate: month_range.begin.iso8601,
        endDate: month_range.end.iso8601
      })
      body = JSON.parse(response.body).fetch("response", {})

      {
        ok: true,
        data: {
          total_impressions: body["impressions"],
          total_engagements: body["engagements"],
          driving_directions_count: body.dig("engagementBreakdown", "drivingDirections"),
          website_clicks_count: body.dig("engagementBreakdown", "websiteClicks")
        }
      }
    rescue Faraday::Error => e
      { ok: false, error: e.message }
    end

    def fetch_ai_visibility
      response = api_connection.get("/v2/accounts/me/scout/ai-visibility", { locationId: external_id })
      body = JSON.parse(response.body).fetch("response", {})

      {
        overall_score: body["overallScore"],
        previous_score: body["previousScore"],
        google_rank: body["googleRank"],
        ai_rank: body["aiRank"],
        sentiment_positive_pct: body.dig("sentiment", "positive"),
        sentiment_neutral_pct: body.dig("sentiment", "neutral"),
        sentiment_negative_pct: body.dig("sentiment", "negative"),
        citation_own_site_pct: body.dig("citationSources", "ownSite"),
        citation_listings_pct: body.dig("citationSources", "listings"),
        citation_reputation_pct: body.dig("citationSources", "reputation"),
        citation_third_party_pct: body.dig("citationSources", "thirdParty"),
        platform_scores: PLATFORM_KEYS.filter_map { |key| [ key, body.dig("platformScores", key) ] if body.dig("platformScores", key) }.to_h
      }
    rescue Faraday::Error
      nil
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

    def api_connection
      connection(BASE_URL, headers: { "Content-Type" => "application/json" })
        .tap { |conn| conn.params["api_key"] = credentials["api_key"]; conn.params["v"] = API_VERSION }
    end
  end
end
