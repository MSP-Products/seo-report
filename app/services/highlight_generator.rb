# Builds the two AI-generated report banners (SOW #4):
#   - a general "highlights" summary (every ongoing report)
#   - an AI SEO update (only when this month's report has AI visibility data)
#
# Guardrails, enforced via the prompt: only reference facts/numbers already
# present in this month's persisted report data, 2-3 sentences max, and
# return null for a banner rather than inventing filler when there's nothing
# genuinely positive to say.
#
# Recommended model: claude-haiku-4-5 — this is grounded summarization of a
# small, well-structured JSON blob, not a task that needs a larger model.
#
# Never raises: with no ANTHROPIC_API_KEY configured, or on any API/parse
# failure, returns nils so report generation proceeds without a highlight
# banner (the view already omits the section entirely when blank).
class HighlightGenerator
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages".freeze
  MODEL = "claude-haiku-4-5".freeze

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You write short client-facing highlight banners for a monthly SEO report.

    Rules:
    - Only reference facts and numbers present in the JSON provided. Never invent
      figures, comparisons, or claims not directly supported by that data.
    - Each banner is at most 2-3 sentences.
    - If there is genuinely nothing positive to report this month, return null
      for that banner instead of writing filler.
    - Only write "ai_seo_summary" if "ai_visibility" data is present in the input.
    - Respond with strict JSON only, matching: {"summary": string|null, "ai_seo_summary": string|null}
  PROMPT

  def initialize(monthly_report)
    @monthly_report = monthly_report
  end

  def call
    return blank_result if api_key.blank?

    response = connection.post("/v1/messages") do |req|
      req.headers["x-api-key"] = api_key
      req.headers["anthropic-version"] = "2023-06-01"
      req.headers["content-type"] = "application/json"
      req.body = {
        model: MODEL,
        max_tokens: 400,
        system: SYSTEM_PROMPT,
        messages: [ { role: "user", content: report_data.to_json } ]
      }.to_json
    end

    parse(response.body)
  rescue Faraday::Error => e
    Rails.logger.warn("HighlightGenerator: request failed — #{e.message}")
    blank_result
  end

  private

  attr_reader :monthly_report

  def api_key
    ENV["ANTHROPIC_API_KEY"]
  end

  def connection
    Faraday.new(url: "https://api.anthropic.com") do |f|
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
  end

  def parse(body)
    text = JSON.parse(body).dig("content", 0, "text")
    parsed = JSON.parse(text)

    { summary_text: parsed["summary"], ai_seo_summary_text: parsed["ai_seo_summary"] }
  rescue JSON::ParserError, TypeError => e
    Rails.logger.warn("HighlightGenerator: could not parse model response — #{e.message}")
    blank_result
  end

  def blank_result
    { summary_text: nil, ai_seo_summary_text: nil }
  end

  # Only the data the model is allowed to reference — deliberately excludes
  # anything not already computed/persisted onto this month's report.
  def report_data
    traffic = monthly_report.report_traffic
    citation = monthly_report.report_citation
    gbp = monthly_report.report_gbp_summary
    ai = monthly_report.report_ai_visibility

    {
      practice_name: monthly_report.client.name,
      report_month: monthly_report.report_month.strftime("%B %Y"),
      traffic: traffic && {
        total_visits: traffic.total_visits, organic_visits: traffic.organic_visits,
        appointments_booked: traffic.appointments_booked, estimated_revenue: traffic.estimated_revenue
      },
      citation: citation && { total_impressions: citation.total_impressions, total_engagements: citation.total_engagements },
      gbp: gbp && {
        average_rating: gbp.average_rating, total_reviews: gbp.total_reviews,
        new_positive_reviews: gbp.new_positive_reviews, new_negative_reviews: gbp.new_negative_reviews
      },
      keyword_gains: monthly_report.report_keyword_rankings.filter_map { |row|
        next if row.previous_position.nil? || row.position.nil? || row.position >= row.previous_position

        { keyword: row.keyword.keyword, previous_position: row.previous_position, position: row.position }
      },
      ai_visibility: ai && {
        overall_score: ai.overall_score, previous_score: ai.previous_score,
        google_rank: ai.google_rank, ai_rank: ai.ai_rank
      }
    }.compact
  end
end
