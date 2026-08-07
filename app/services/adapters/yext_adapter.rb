module Adapters
  # Yext covers three report sections (SOW #4): Citation & Directory
  # Performance, AI Visibility (Scout), and Google Business Profile activity
  # (SOW lists GBP as "Yext or GBP directly — TBD"; resolved in favor of
  # Yext, via its Reviews/Social/Knowledge-Graph APIs rather than Google's own).
  #
  # Credentials shape: {"api_key" => "..."}. external_id: the Yext entity ID.
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

    # A direct entity lookup by ID — the lightest already-used call (see
    # fetch_photos) that 404s on a deleted/wrong entity ID without running
    # any analytics report.
    def check_connection
      return Result.failure("yext: no entity id configured for this client") if external_id.blank?

      api_connection.get("/v2/accounts/me/entities/#{external_id}")
      Result.success
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
      degrade(nil) do
        row = run_report(
          metrics: AI_VISIBILITY_METRICS.values, dimensions: [ "ENTITY_IDS" ],
          filters: { entityIds: [ external_id ] }
        )
        next nil if row.nil?

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
      end
    end

    def fetch_platform_scores
      degrade({}) do
        rows = run_report_rows(
          metrics: [ AI_VISIBILITY_METRICS[:ai_rank] ], dimensions: [ "AI_MODEL", "ENTITY_IDS" ],
          filters: { entityIds: [ external_id ] }
        )

        rows.to_a.filter_map do |row|
          platform = row["AI_MODEL"]
          next if platform.blank?

          [ platform.downcase, metric_value(row, %w[AI_MODEL ENTITY_IDS]) ]
        end.to_h
      end
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

    # Lifetime totals, from an unfiltered call — a date-filtered call's own
    # "count"/"averageRating" reflect only that filtered subset, not the
    # account's true lifetime totals.
    def fetch_review_summary
      degrade({ total_reviews: nil, average_rating: nil }) do
        response = api_connection.get(REVIEWS_PATH, { entityIds: external_id, limit: 1 })
        body = response_data(response) || {}

        { total_reviews: body["count"], average_rating: body["averageRating"] }
      end
    end

    def fetch_reviews_this_month
      degrade([]) do
        response = api_connection.get(REVIEWS_PATH, {
          entityIds: external_id, limit: 100,
          minPublisherDate: month_range.begin.iso8601, maxPublisherDate: month_range.end.iso8601
        })
        reviews = response_data(response, "reviews") || []

        reviews.map do |r|
          owner_reply = Array(r["comments"]).find { |c| c["authorRole"] == "BUSINESS_OWNER" }

          {
            external_id: r["id"], author_name: r["authorName"], rating: r["rating"],
            body: r["content"], posted_at: epoch_millis_to_time(r["publisherDate"]),
            owner_reply_text: owner_reply&.fetch("content", nil),
            owner_replied_at: owner_reply && epoch_millis_to_time(owner_reply["publisherDate"])
          }
        end
      end
    end

    # No documented server-side date filter for this endpoint (unlike
    # reviews), so this filters client-side instead.
    def fetch_posts_this_month
      degrade([]) do
        response = api_connection.get(POSTS_PATH, { entityIds: external_id, limit: 50 })
        posts = response_data(response, "posts") || []

        posts.filter_map do |p|
          published_at = p["postDate"].presence && Time.zone.parse(p["postDate"])
          next unless published_at && month_range.cover?(published_at.to_date)

          { title: p["postTitle"], description: p["text"], published_at: published_at }
        end
      end
    end

    # Not a GBP-specific endpoint at all — the Knowledge Graph entity's own
    # photoGallery field, covered by the same permission Citations already use.
    def fetch_photos
      degrade([]) do
        response = api_connection.get("/v2/accounts/me/entities/#{external_id}")
        gallery = response_data(response, "photoGallery") || []

        gallery.map { |photo| { image_url: photo.dig("image", "url"), caption: photo["description"] } }
      end
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

      response_data(response, "data")
    end

    def response_data(response, *keys)
      JSON.parse(response.body).dig("response", *keys)
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
