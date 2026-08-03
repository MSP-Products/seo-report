# Wraps a MonthlyReport for the public report view: keeps DB access and
# runtime-only computations (gained/held/dropped, MoM deltas) out of the views,
# per CONVENTIONS.md #11.
class ReportPresenter
  delegate :report_month, :access_token, :client, to: :monthly_report

  attr_reader :monthly_report

  # A client can have 80+ tracked keywords (SEMrush plan dependent) — paginate
  # rather than render them all in one table on a page read mostly on phones.
  KEYWORDS_PER_PAGE = 10

  def initialize(monthly_report, keyword_page: nil)
    @monthly_report = monthly_report
    @requested_keyword_page = keyword_page
  end

  def month_label
    report_month.strftime("%B %Y")
  end

  def first_report?
    monthly_report.is_first_report?
  end

  # Other months already generated for this client, newest first — never includes
  # the current in-progress month, since a report only exists once generated
  # (SOW #6: "can only be filtered/viewed by fully completed months").
  def available_months
    client.monthly_reports.generated.order(report_month: :desc)
  end

  def highlight
    monthly_report.report_highlight
  end

  def general_summary
    highlight&.summary_text
  end

  def ai_seo_summary
    highlight&.ai_seo_summary_text
  end

  def traffic
    monthly_report.report_traffic
  end

  # GA4 isn't wired up yet — total_visits stays nil until that integration exists.
  def ga4_available?
    traffic&.total_visits.present?
  end

  def ghl_connected?
    traffic&.ghl_data_status == "connected"
  end

  def visits_by_source
    return [] unless ga4_available?

    [
      { label: "Organic", value: traffic.organic_visits },
      { label: "Direct", value: traffic.direct_visits },
      { label: "Referral", value: traffic.referral_visits },
      { label: "Paid", value: traffic.paid_visits }
    ]
  end

  def visit_share_pct(value)
    return 0 if traffic&.total_visits.to_i.zero? || value.nil?

    ((value.to_f / traffic.total_visits) * 100).round
  end

  def citation
    monthly_report.report_citation
  end

  def citation_impressions_change_pct
    percent_change(citation&.total_impressions, citation&.previous_impressions)
  end

  def citation_engagements_change_pct
    percent_change(citation&.total_engagements, citation&.previous_engagements)
  end

  def engagement_share_pct(count)
    return 0 if citation&.total_engagements.to_i.zero? || count.nil?

    ((count.to_f / citation.total_engagements) * 100).round
  end

  # Only present for months where the client was AI-SEO-enrolled at generation
  # time — frozen per report, not re-derived from client.ai_seo_enrolled?, so a
  # later enrollment change never retroactively alters past reports.
  def ai_visibility
    monthly_report.report_ai_visibility
  end

  def ai_visibility_available?
    ai_visibility.present?
  end

  def gbp_summary
    monthly_report.report_gbp_summary
  end

  def gbp_posts
    monthly_report.gbp_posts.sort_by { |post| post.published_at || Date.new(1, 1, 1) }.reverse
  end

  def gbp_reviews
    monthly_report.gbp_reviews.sort_by { |review| review.posted_at || Date.new(1, 1, 1) }.reverse
  end

  def gbp_photos
    monthly_report.gbp_photos
  end

  def needs_photos?
    gbp_summary&.needs_photos? && gbp_photos.empty?
  end

  def pages_published
    monthly_report.report_pages_published
  end

  def keyword_rows
    @keyword_rows ||= monthly_report.report_keyword_rankings
      .sort_by { |row| row.keyword.keyword }
  end

  # The full set backs the summary counts below (gained/held/dropped,
  # top10/top3) regardless of which page is being viewed — only the table
  # itself paginates.
  def paginated_keyword_rows
    offset = (keyword_page - 1) * KEYWORDS_PER_PAGE
    keyword_rows[offset, KEYWORDS_PER_PAGE] || []
  end

  def keyword_page
    @keyword_page ||= [ [ @requested_keyword_page.to_i, 1 ].max, keyword_total_pages ].min
  end

  def keyword_total_pages
    @keyword_total_pages ||= [ (keyword_rows.size / KEYWORDS_PER_PAGE.to_f).ceil, 1 ].max
  end

  def keywords_tracked_count
    keyword_rows.size
  end

  def keywords_top10_count
    keyword_rows.count { |row| ranked_top?(row.position, 10) }
  end

  def keywords_top3_count
    keyword_rows.count { |row| ranked_top?(row.position, 3) }
  end

  # A keyword only counts toward gained/held/dropped once it had a tracked
  # position last month — a keyword with no prior ranking is a fresh addition,
  # not a "drop", and shouldn't skew the summary counts.
  def keyword_movement(row)
    return nil if row.previous_position.nil?
    return :dropped if row.position.nil?
    return :gained if row.position < row.previous_position
    return :dropped if row.position > row.previous_position

    :held
  end

  def keyword_change(row)
    return nil if row.previous_position.nil? || row.position.nil?

    row.previous_position - row.position
  end

  def keyword_gained_count
    keyword_rows.count { |row| keyword_movement(row) == :gained }
  end

  def keyword_held_count
    keyword_rows.count { |row| keyword_movement(row) == :held }
  end

  def keyword_dropped_count
    keyword_rows.count { |row| keyword_movement(row) == :dropped }
  end

  private

  def ranked_top?(position, threshold)
    position.present? && position <= threshold
  end

  def percent_change(current, previous)
    return nil if current.nil? || previous.nil? || previous.zero?

    ((current - previous).to_f / previous * 100).round
  end
end
