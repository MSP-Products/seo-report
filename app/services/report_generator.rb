# Orchestrates one client's MonthlyReport for a given month: runs each
# service adapter, upserts the corresponding Report* rows, and logs the
# attempt. Idempotent — safe to re-run for the same client/month (e.g. to
# retry after a partial failure); re-running replaces that month's synced
# data rather than duplicating it.
#
# HubSpot, Google Analytics, Yext, and SEMrush are mandatory: any failure
# raises AdapterFailureError, aborting the whole run — a client is assumed
# to have all four properly configured, so a failure here is something to
# fix, not a placeholder to render. GHL and AI SEO are the two opt-in
# exceptions: a client with no GHL link, or not enrolled in AI SEO, simply
# has that section omitted — but once a client *is* opted in, that source
# becomes mandatory for them too (a configured GHL link or an AI-SEO-enrolled
# client whose sync fails also raises). Any exception marks the attempt
# "failed" and logs it.
class ReportGenerator
  include MonthlyRange

  class MonthNotCompleteError < StandardError; end
  class AdapterFailureError < StandardError; end

  def initialize(client:, month:)
    @client = client
    @month = month.to_date.beginning_of_month
  end

  def call
    if month >= Date.current.beginning_of_month
      raise MonthNotCompleteError, "cannot generate a report for the current or a future month"
    end

    report = find_or_create_report
    mark_generating(report)

    sync_hubspot(report)
    sync_traffic(report)
    sync_yext(report)
    sync_keywords(report)
    sync_pages_published(report)
    sync_highlights(report) unless report.is_first_report?

    mark_ready(report)
    log_attempt(report, status: "success")
    report
  rescue StandardError => e
    mark_failed(report) if report
    log_attempt(report, status: "failed", fatal_error: e) if report
    raise
  end

  private

  attr_reader :client, :month

  def find_or_create_report
    client.find_or_create_monthly_report(month)
  end

  def mark_generating(report)
    report.update!(generation_status: "generating", attempt_count: report.attempt_count + 1,
      generation_started_at: Time.current)
  end

  def mark_ready(report)
    report.update!(generated_at: Time.current, generation_status: "ready")
  end

  def mark_failed(report)
    report.update!(generation_status: "failed")
  end

  def previous_report
    return @previous_report if defined?(@previous_report)

    @previous_report = client.monthly_reports.find_by(report_month: month - 1.month)
  end

  def sync_hubspot(report)
    result = SyncClientFromHubspot.new(client).call
    raise AdapterFailureError, "hubspot: #{result.error}" unless result.success?
  end

  def sync_traffic(report)
    traffic = report.report_traffic || report.build_report_traffic

    ga4_result = Adapters::GoogleAnalyticsAdapter.new(client, report_month: month).call
    raise AdapterFailureError, "google_analytics: #{ga4_result.error}" unless ga4_result.success?

    traffic.assign_attributes(ga4_result.data)

    if client.client_service_links.exists?(service: "ghl")
      ghl_result = Adapters::GhlAdapter.new(client, report_month: month).call
      raise AdapterFailureError, "ghl: #{ghl_result.error}" unless ghl_result.success?

      traffic.assign_attributes(ghl_result.data)
    else
      traffic.ghl_data_status = "not_connected"
    end

    traffic.save!
  end

  def sync_yext(report)
    result = Adapters::YextAdapter.new(client, report_month: month).call
    raise AdapterFailureError, "yext: #{result.error}" unless result.success?

    sync_citations(report, result.data[:citations])
    sync_ai_visibility(report, result.data[:ai_visibility])
    sync_gbp_activity(report, result.data[:gbp])
  end

  def sync_citations(report, citations)
    return if citations.blank?

    previous = previous_report&.report_citation
    report.report_citation&.destroy
    report.create_report_citation!(
      total_impressions: citations[:total_impressions],
      total_engagements: citations[:total_engagements],
      driving_directions_count: citations[:driving_directions_count],
      website_clicks_count: citations[:website_clicks_count],
      previous_impressions: previous&.total_impressions,
      previous_engagements: previous&.total_engagements
    )
  end

  # Frozen per report, not re-derived from client.ai_seo_enrolled? later — see
  # ReportPresenter#ai_visibility_available? for why.
  #
  # Not enrolled: skip entirely, same as an unconfigured service — not every
  # client buys AI SEO. Enrolled: this data is mandatory, same as any other
  # opted-in source (see GHL in #sync_traffic) — a blank payload here is a
  # real failure, not a placeholder.
  def sync_ai_visibility(report, ai)
    return unless client.ai_seo_enrolled?

    raise AdapterFailureError, "yext: no AI visibility data returned for an AI-SEO-enrolled client" if ai.blank?

    previous = previous_report&.report_ai_visibility
    report.report_ai_visibility&.destroy
    visibility = report.create_report_ai_visibility!(
      overall_score: ai[:overall_score],
      previous_score: previous&.overall_score,
      google_rank: ai[:google_rank],
      ai_rank: ai[:ai_rank],
      sentiment_positive_pct: ai[:sentiment_positive_pct],
      sentiment_neutral_pct: ai[:sentiment_neutral_pct],
      sentiment_negative_pct: ai[:sentiment_negative_pct],
      citation_own_site_pct: ai[:citation_own_site_pct],
      citation_listings_pct: ai[:citation_listings_pct],
      citation_reputation_pct: ai[:citation_reputation_pct],
      citation_third_party_pct: ai[:citation_third_party_pct]
    )

    ai[:platform_scores].to_h.each do |platform, score|
      visibility.report_ai_platform_scores.create!(platform: platform, score: score)
    end
  end

  # needs_action/needs_photos thresholds are provisional (SOW #9 leaves the
  # exact criteria undefined) — rating <= 2 and "zero photos synced this
  # month", pending MSP's actual thresholds.
  def sync_gbp_activity(report, gbp)
    return if gbp.blank?

    reviews = Array(gbp[:reviews])
    photos = Array(gbp[:photos])

    report.report_gbp_summary&.destroy
    report.create_report_gbp_summary!(
      total_reviews: gbp[:total_reviews],
      average_rating: gbp[:average_rating],
      new_positive_reviews: reviews.count { |r| r[:rating].to_i >= 4 },
      new_negative_reviews: reviews.count { |r| r[:rating].to_i <= 2 },
      needs_photos: photos.empty?
    )

    report.gbp_posts.destroy_all
    Array(gbp[:posts]).each do |post|
      report.gbp_posts.create!(title: post[:title], description: post[:description], published_at: post[:published_at])
    end

    report.gbp_reviews.destroy_all
    reviews.each do |review|
      sentiment = review[:rating].to_i <= 2 ? "negative" : (review[:rating].to_i == 3 ? "neutral" : "positive")
      report.gbp_reviews.create!(
        external_id: review[:external_id], author_name: review[:author_name], rating: review[:rating],
        body: review[:body], posted_at: review[:posted_at], sentiment: sentiment,
        needs_action: review[:rating].to_i <= 2 && review[:owner_reply_text].blank?,
        owner_reply_text: review[:owner_reply_text], owner_replied_at: review[:owner_replied_at]
      )
    end

    report.gbp_photos.destroy_all
    photos.each { |photo| report.gbp_photos.create!(image_url: photo[:image_url], caption: photo[:caption]) }
  end

  def sync_keywords(report)
    result = Adapters::SemrushAdapter.new(client, report_month: month).call
    raise AdapterFailureError, "semrush: #{result.error}" unless result.success?

    result.data[:rankings].each do |ranking|
      previous_position = previous_report&.report_keyword_rankings
        &.find_by(keyword_id: ranking[:client_keyword_id])&.position

      report.report_keyword_rankings.find_or_initialize_by(keyword_id: ranking[:client_keyword_id]).update!(
        position: ranking[:position],
        potential_traffic: ranking[:potential_traffic],
        growth: ranking[:growth],
        keyword_difficulty: ranking[:keyword_difficulty],
        intent: ranking[:intent],
        serp_features: ranking[:serp_features],
        previous_position: previous_position
      )
    end
  end

  # Only reads pages SitemapScanner has already discovered — this doesn't
  # trigger a scan itself, since site scanning runs on its own recurring
  # schedule (config/recurring.yml), independent of report generation.
  def sync_pages_published(report)
    report.report_pages_published.destroy_all

    client.sitemap_pages.where(first_seen_at: month_range).find_each do |page|
      report.report_pages_published.create!(
        sitemap_page: page, url: page.url, title: page.title, description: page.meta_description
      )
    end
  end

  def month_range
    month_range_for(month)
  end

  def sync_highlights(report)
    highlight_data = HighlightGenerator.new(report).call
    return if highlight_data[:summary_text].blank? && highlight_data[:ai_seo_summary_text].blank?

    report.report_highlight&.destroy
    report.create_report_highlight!(
      summary_text: highlight_data[:summary_text],
      ai_seo_summary_text: highlight_data[:ai_seo_summary_text],
      generated_at: Time.current,
      model_used: HighlightGenerator::MODEL
    )
  end

  def log_attempt(report, status:, fatal_error: nil)
    record_generation_log(report, status: status, fatal_error: fatal_error)
    log_to_rails_logger(status: status, fatal_error: fatal_error)
  end

  def record_generation_log(report, status:, fatal_error: nil)
    report.report_generation_logs.create!(
      status: status,
      attempted_at: Time.current,
      error_summary: fatal_error&.message,
      error_log: fatal_error&.message
    )
  end

  def log_to_rails_logger(status:, fatal_error: nil)
    practice_month = "#{client.name}'s #{month.strftime("%B %Y")} report"

    if status == "success"
      Rails.logger.info("ReportGenerator: generated #{practice_month}")
    else
      Rails.logger.error("ReportGenerator: failed to generate #{practice_month} — #{fatal_error&.message}")
    end
  end
end
