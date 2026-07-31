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
  # Endpoint and response shape both confirmed live against a real project:
  #   - No "/rankings" suffix; type=tracking_position_organic + action=report
  #     are required.
  #   - The response is JSON, not the semicolon-delimited text the classic
  #     Domain Analytics reports use — and export_columns is silently
  #     ignored here; this report always returns its own fixed field set.
  #   - Each row is keyed by index under "data". "Ph" is the keyword phrase.
  #     "Fi"/"Be" are keyed by url mask and give the most-recent/earliest
  #     ranking position in the requested date range (confirmed by
  #     cross-checking against the per-date "Dt" breakdown) — "-" means not
  #     ranked. previous_position is still our own historical record (see
  #     ReportGenerator), not read from SEMrush's own Be/Diff figures.
  #
  # LOWER CONFIDENCE: "Tr" (traffic share, keyed by date then url mask) is
  # the closest available stand-in for potential_traffic — SEMrush doesn't
  # expose a dedicated "potential traffic" figure on this report, so this is
  # an approximation, not a confirmed match to the old semantic.
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
      domain = client.website_url.to_s.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").sub(%r{/\z}, "")
      "*.#{domain}/*"
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
