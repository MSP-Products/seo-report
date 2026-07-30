module Adapters
  # SEMrush Position Tracking + Trends APIs, per-client domain tracking
  # (SOW #4). Returns current rankings only — month-over-month
  # previous_position is our own historical record, not something SEMrush is
  # asked for (see ReportGenerator, which carries last month's `position`
  # forward into this month's `previous_position`).
  #
  # Credentials shape: {"api_key" => "..."}.
  # external_id: the SEMrush Position Tracking project ID for this client's
  # tracked domain (client.website_url).
  #
  # LOWER CONFIDENCE: the exact export_columns codes/endpoint path for
  # Position Tracking + Trends are a best-effort reconstruction from SEMrush's
  # public API docs, not verified against a live project — re-check column
  # meanings once real credentials/a real project are available.
  class SemrushAdapter < Base
    SERVICE = "semrush"
    BASE_URL = "https://api.semrush.com"

    private

    def perform
      return Result.failure("semrush: no project id configured for this client") if external_id.blank?

      keywords = client.client_keywords.active
      return Result.success(rankings: []) if keywords.empty?

      response = connection(BASE_URL).get("/reports/v1/projects/#{external_id}/tracking/rankings", {
        key: credentials["api_key"],
        domain: client.website_url,
        export_columns: "Ph,Po,Pp"
      })

      rows_by_keyword = parse_rankings(response.body)

      rankings = keywords.map do |keyword|
        row = rows_by_keyword[keyword.keyword]
        {
          client_keyword_id: keyword.id,
          position: row && row[:position],
          potential_traffic: row && row[:potential_traffic]
        }
      end

      Result.success(rankings: rankings)
    end

    # SEMrush's classic reporting APIs return semicolon-delimited CSV-style
    # text (`Ph;Po;Pp` per requested export_columns), not JSON.
    def parse_rankings(body)
      body.to_s.each_line.drop(1).each_with_object({}) do |line, memo|
        keyword, position, potential_traffic = line.strip.split(";")
        next if keyword.blank?

        memo[keyword] = { position: position&.to_i, potential_traffic: potential_traffic&.to_f }
      end
    end
  end
end
