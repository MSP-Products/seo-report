module Adapters
  # SEMrush Position Tracking + Trends APIs, per-client domain tracking
  # (SOW #4). Returns current rankings only — month-over-month
  # previous_position is our own historical record, not something SEMrush is
  # asked for (see ReportGenerator, which carries last month's `position`
  # forward into this month's `previous_position`).
  #
  # Credentials shape: {"api_key" => "..."}.
  # external_id: the SEMrush Position Tracking campaign ID for this client's
  # tracked domain (client.website_url) — note this is the FULL
  # "{project_id}_{campaign_id}" pair from the project's Position Tracking
  # URL (e.g. semrush.com/tracking/landscape/30632499_5220001.html), not the
  # shorter project ID shown on the domain overview page. The API returns
  # "campaign not found" if only the project ID half is sent.
  #
  # No "/rankings" suffix; type=tracking_position_organic + action=report are
  # required. Response is JSON (not the classic Domain Analytics reports'
  # semicolon-delimited text) with its own fixed field set — export_columns
  # is silently ignored. Per row: "Ph" is the keyword phrase; "Fi"/"Be" (keyed
  # by url mask) give the most-recent/earliest ranking position in range,
  # "-" meaning not ranked.
  #
  # LOWER CONFIDENCE: "Tr" (traffic share) is the closest stand-in for
  # potential_traffic — SEMrush has no dedicated "potential traffic" figure.
  class SemrushAdapter < Base
    SERVICE = "semrush"
    BASE_URL = "https://api.semrush.com"
    # Comfortably above any realistic per-client tracked-keyword count — the
    # report defaults to 10 rows per page and doesn't paginate otherwise.
    DISPLAY_LIMIT = 500

    private

    def perform
      return Result.failure("semrush: no project id configured for this client") if external_id.blank?

      keywords = client.client_keywords.active
      return Result.success(rankings: []) if keywords.empty?

      response = connection(BASE_URL).get("/reports/v1/projects/#{external_id}/tracking/", {
        key: credentials["api_key"],
        type: "tracking_position_organic",
        action: "report",
        url: tracked_url_mask,
        display_limit: DISPLAY_LIMIT
      })

      rows_by_keyword = parse_rankings(response.body)

      rankings = keywords.map do |keyword|
        row = rows_by_keyword[keyword.keyword.downcase]
        {
          client_keyword_id: keyword.id,
          position: row && row[:position],
          potential_traffic: row && row[:potential_traffic]
        }
      end

      Result.success(rankings: rankings)
    end

    # A wildcard mask ("*.example.com/*") matching however the tracked URL was
    # registered when the Position Tracking project was set up in SEMrush.
    def tracked_url_mask
      @tracked_url_mask ||= begin
        domain = client.website_url.to_s.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").sub(%r{/\z}, "")
        "*.#{domain}/*"
      end
    end

    def parse_rankings(body)
      rows = JSON.parse(body).fetch("data", {}).values

      rows.each_with_object({}) do |row, memo|
        keyword = row["Ph"]
        next if keyword.blank?

        position = row.dig("Fi", tracked_url_mask)
        traffic_by_date = row["Tr"] || {}
        latest_date = traffic_by_date.keys.max

        memo[keyword.downcase] = {
          position: (position if position.is_a?(Numeric)),
          potential_traffic: traffic_by_date.dig(latest_date, tracked_url_mask)
        }
      end
    end
  end
end
