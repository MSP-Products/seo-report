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
  # GBP reviews/posts/photos below are also verified live: Reviews and Posts
  # (Reviews/Social Management APIs — needed their own App permission, a
  # separate INSUFFICIENT_APP_ACCESS 403 from the Analytics one) confirmed
  # against a real account with real data. Photos turned out not to be a GBP
  # endpoint at all — they're the Knowledge Graph entity's own photoGallery
  # field, already covered by the same permission Citations/AI Visibility use.
  #   - total_reviews/average_rating are lifetime aggregates, from an
  #     unfiltered reviews call — a date-filtered call's own "count" reflects
  #     only the filtered results, not the lifetime total (confirmed: filtering
  #     to one month returned count: 1, not the account's true lifetime 134).
  #   - Review dates are epoch milliseconds; post dates are plain
  #     "YYYY-MM-DD HH:MM:SS" strings — two different formats from the same
  #     product.
  #   - minPublisherDate/maxPublisherDate does filter server-side for reviews
  #     (confirmed) — the Posts endpoint isn't documented as supporting
  #     server-side date filtering, so posts are filtered client-side instead.
  #   - A review's owner reply is buried in its own "comments" array
  #     (authorRole: "BUSINESS_OWNER") — schema already had
  #     owner_replied_at/owner_reply_text columns that nothing populated
  #     before this.
  class YextAdapter < Base
    SERVICE = "yext"
    BASE_URL = "https://api.yextapis.com"
    API_VERSION = "20240101"
    REPORTS_PATH = "/v2/accounts/me/analytics/reports".freeze
    REVIEWS_PATH = "/v2/accounts/me/reviews".freeze
    POSTS_PATH = "/v2/accounts/me/posts".freeze

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
      summary = fetch_review_summary

      {
        total_reviews: summary[:total_reviews],
        average_rating: summary[:average_rating],
        reviews: fetch_reviews_this_month,
        posts: fetch_posts_this_month,
        photos: fetch_photos
      }
    end

    # Lifetime aggregates across the whole GBP listing — distinct from the
    # per-review list below, which is just this month's new reviews. A
    # date-filtered call's own "count"/"averageRating" only reflect the
    # filtered subset, not the true lifetime totals, so this is a separate,
    # unfiltered call.
    def fetch_review_summary
      response = api_connection.get(REVIEWS_PATH, { entityIds: external_id, limit: 1 })
      body = JSON.parse(response.body).fetch("response", {})

      { total_reviews: body["count"], average_rating: body["averageRating"] }
    rescue Faraday::Error
      { total_reviews: nil, average_rating: nil }
    end

    def fetch_reviews_this_month
      response = api_connection.get(REVIEWS_PATH, {
        entityIds: external_id, limit: 100,
        minPublisherDate: month_range.begin.iso8601, maxPublisherDate: month_range.end.iso8601
      })
      reviews = JSON.parse(response.body).dig("response", "reviews") || []

      reviews.map do |r|
        owner_reply = Array(r["comments"]).find { |c| c["authorRole"] == "BUSINESS_OWNER" }

        {
          external_id: r["id"], author_name: r["authorName"], rating: r["rating"],
          body: r["content"], posted_at: epoch_millis_to_time(r["publisherDate"]),
          owner_reply_text: owner_reply&.fetch("content", nil),
          owner_replied_at: owner_reply && epoch_millis_to_time(owner_reply["publisherDate"])
        }
      end
    rescue Faraday::Error
      []
    end

    # No documented server-side date filter for this endpoint (unlike
    # reviews), so this filters client-side instead.
    def fetch_posts_this_month
      response = api_connection.get(POSTS_PATH, { entityIds: external_id, limit: 50 })
      posts = JSON.parse(response.body).dig("response", "posts") || []

      posts.filter_map do |p|
        published_at = p["postDate"].presence && Time.zone.parse(p["postDate"])
        next unless published_at && month_range.cover?(published_at.to_date)

        { title: p["postTitle"], description: p["text"], published_at: published_at }
      end
    rescue Faraday::Error
      []
    end

    # Not a GBP-specific endpoint at all — the Knowledge Graph entity's own
    # photoGallery field, covered by the same permission Citations already use.
    def fetch_photos
      response = api_connection.get("/v2/accounts/me/entities/#{external_id}")
      gallery = JSON.parse(response.body).dig("response", "photoGallery") || []

      gallery.map { |photo| { image_url: photo.dig("image", "url"), caption: photo["description"] } }
    rescue Faraday::Error
      []
    end

    def epoch_millis_to_time(millis)
      millis && Time.at(millis / 1000.0)
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
