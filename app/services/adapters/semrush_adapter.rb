module Adapters
  # SEMrush Position Tracking + Keyword Overview bulk APIs, per-client domain
  # tracking (SOW #4: "rankings, gained/held/dropped, KD%"). Returns current
  # rankings only — month-over-month previous_position is our own historical
  # record, not something SEMrush is asked for (see ReportGenerator, which
  # carries last month's `position` forward into this month's
  # `previous_position`).
  #
  # The tracked keyword SET is discovered from SEMrush, not curated here. A
  # client can have 80+ keywords tracked directly in their SEMrush Position
  # Tracking project — requiring a developer to hand-add each one via
  # ClientKeyword would never keep up. Every keyword phrase in a Position
  # Tracking response gets `find_or_create_by!`'d onto ClientKeyword, then
  # `ClientKeyword#active` (default true) becomes an opt-OUT: MSP can mark
  # one inactive to hide an irrelevant SEMrush-tracked term (e.g. informational
  # long-tail content) from the client-facing report without touching SEMrush
  # itself, rather than an opt-in list someone has to build up front.
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
  # `growth` is derived from that same "Tr" series (latest minus earliest
  # date in the range) rather than a second call — SEMrush exposes no
  # separate "growth" figure either. Nil until a project has 2+ tracked
  # dates, which is expected for a first report.
  #
  # Keyword Difficulty, Intent, and SERP Features all come from one genuinely
  # separate bulk endpoint (type=phrase_this — the classic "Keyword Overview"
  # report, confirmed live against MSP's account to support semicolon-joined
  # bulk phrases despite being named for a single keyword). It requires a
  # `database` region ("us" — MSP's practices are all US-based) and is not
  # part of the Position Tracking response. A failure here degrades every
  # keyword's Kd/Intent/SF to nil rather than failing the whole adapter call
  # — it's supplementary to ranking data, not load-bearing.
  class SemrushAdapter < Base
    SERVICE = "semrush"
    BASE_URL = "https://api.semrush.com"
    # Comfortably above MSP's current SEMrush plan's total Keywords quota
    # (140) — bump this if the plan is ever upgraded to a higher tier.
    DISPLAY_LIMIT = 500
    OVERVIEW_DATABASE = "us"
    # SEMrush's bulk Keyword Overview endpoint accepts a semicolon-joined
    # phrase list per request; keep well under its documented cap so one
    # client's keyword count never has to paginate.
    OVERVIEW_BATCH_SIZE = 100
    # SEMrush's numeric Search Intent codes, confirmed live against known
    # commercial/transactional/informational keywords. "Navigational" (2) is
    # unconfirmed against a real example but documented by SEMrush alongside
    # the other three.
    INTENT_CODES = { "0" => "C", "1" => "I", "2" => "N", "3" => "T" }.freeze

    private

    def perform
      return Result.failure("semrush: no project id configured for this client") if external_id.blank?

      rows_by_keyword = parse_rankings(fetch_rankings.body)
      return Result.success(rankings: []) if rows_by_keyword.empty?

      keywords = rows_by_keyword.keys.map { |phrase| find_or_create_keyword(phrase) }.select(&:active?)
      overview_by_keyword = degrade({}) { fetch_keyword_overview(keywords) }

      rankings = keywords.map do |keyword|
        row = rows_by_keyword[keyword.keyword]
        overview = overview_by_keyword[keyword.keyword] || {}
        {
          client_keyword_id: keyword.id,
          position: row[:position],
          potential_traffic: row[:potential_traffic],
          growth: row[:growth],
          keyword_difficulty: overview[:keyword_difficulty],
          intent: overview[:intent],
          serp_features: overview[:serp_features]
        }
      end

      Result.success(rankings: rankings)
    end

    # Reuses the same Position Tracking call #perform makes — SEMrush 404s a
    # bad project ID with a plain-text "campaign not found" body, not a JSON
    # error, so this checks the parse succeeds rather than relying on
    # Base#call's Faraday::Error rescue to catch it.
    def check_connection
      return Result.failure("semrush: no project id configured for this client") if external_id.blank?

      response = fetch_rankings
      return Result.success if valid_rankings_response?(response.body)

      Result.failure("semrush: #{response.body.to_s.strip.presence || "unexpected response"}")
    end

    def valid_rankings_response?(body)
      JSON.parse(body).key?("data")
    rescue JSON::ParserError
      false
    end

    # Phrases from parse_rankings/parse_keyword_overview are already
    # stripped+downcased, so the stored ClientKeyword#keyword and this
    # method's argument always match exactly — no re-normalizing needed at
    # the lookup sites below.
    #
    # create_or_find_by!, not find_or_create_by! — this runs every report
    # generation for every tracked phrase, so it needs to be race-safe
    # against a concurrent retry rather than assuming the SELECT-then-INSERT
    # window never overlaps. Backed by the unique index on
    # (client_id, keyword); a racing INSERT falls back to the existing row
    # instead of raising or duplicating.
    #
    # IMPORTANT: create_or_find_by!'s race fallback is a plain find_by! on
    # the attributes given here — it does NOT re-run ClientKeyword's
    # normalize_keyword callback. That's only safe because `phrase` is
    # already normalized before it gets here. Passing an un-normalized
    # phrase to this method would silently fail to find an existing row on
    # the race path (see test/models/client_keyword_test.rb).
    def find_or_create_keyword(phrase)
      client.client_keywords.create_or_find_by!(keyword: phrase)
    end

    def fetch_rankings
      connection(BASE_URL).get("/reports/v1/projects/#{external_id}/tracking/", {
        key: credentials["api_key"],
        type: "tracking_position_organic",
        action: "report",
        url: tracked_url_mask,
        display_limit: DISPLAY_LIMIT
      })
    end

    def fetch_keyword_overview(keywords)
      keywords.each_slice(OVERVIEW_BATCH_SIZE).each_with_object({}) do |batch, memo|
        response = connection(BASE_URL).get("/", {
          key: credentials["api_key"],
          type: "phrase_this",
          database: OVERVIEW_DATABASE,
          phrase: batch.map(&:keyword).join(";"),
          export_columns: "Ph,Kd,In,Fk"
        })
        memo.merge!(parse_keyword_overview(response.body))
      end
    end

    # "Keyword;Keyword Difficulty Index;Intent;Keywords SERP Features\n
    #  cosmetic dentistry;81;0;3,6,9,13,21,36,43" — semicolon-delimited CSV,
    # the classic SEMrush Analytics API's response shape (unlike Position
    # Tracking, which is JSON). "Fk" is a comma-separated list of SERP
    # feature type codes present for that keyword — we store the count, not
    # the decoded feature names, matching the existing single-integer
    # `serp_features` column.
    def parse_keyword_overview(body)
      lines = body.to_s.strip.lines.map(&:strip)
      lines.drop(1).each_with_object({}) do |line, memo|
        phrase, kd, intent_code, features = line.split(";")
        next if phrase.blank?

        memo[phrase.strip.downcase] = {
          keyword_difficulty: kd.to_i,
          intent: INTENT_CODES[intent_code],
          serp_features: features.to_s.split(",").size
        }
      end
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
        dates = traffic_by_date.keys.sort
        earliest_traffic = traffic_by_date.dig(dates.first, tracked_url_mask)
        latest_traffic = traffic_by_date.dig(dates.last, tracked_url_mask)

        memo[keyword.strip.downcase] = {
          position: (position if position.is_a?(Numeric)),
          potential_traffic: latest_traffic,
          growth: (latest_traffic - earliest_traffic if dates.size > 1 && earliest_traffic && latest_traffic)
        }
      end
    end
  end
end
