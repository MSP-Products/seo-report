module ClientsHelper
  ONBOARDING_STATUS_BADGE = {
    "active" => "bg-emerald-50 text-emerald-700",
    "pending" => "bg-amber-50 text-amber-700",
    "offboarded" => "bg-slate-100 text-slate-600"
  }.freeze

  def client_status_badge_class(client)
    ONBOARDING_STATUS_BADGE.fetch(client.onboarding_status, "bg-slate-100 text-slate-600")
  end

  CLIENT_REPORT_STATUS_BADGE = {
    "queued" => "bg-slate-100 text-slate-600",
    "generating" => "bg-teal-primary/10 text-teal-dark",
    "ready" => "bg-emerald-50 text-emerald-700",
    "sent" => "bg-emerald-50 text-emerald-700",
    "held" => "bg-amber-50 text-amber-700",
    "failed" => "bg-red-50 text-red-700"
  }.freeze

  # A first report's own row reads "First report" rather than "Sent"/"Ready"
  # — it's the one-time baseline, not an ongoing month, and the Report
  # history table (Overview tab) calls this out the same way the mockup does.
  def client_report_status_label(report)
    return "First report" if first_report_badge?(report)
    return "Failed ×#{report.attempt_count}" if report.effective_status == "failed" && report.attempt_count > 1

    report.effective_status.capitalize
  end

  def client_report_status_badge_class(report)
    return "bg-slate-100 text-slate-600" if first_report_badge?(report)

    CLIENT_REPORT_STATUS_BADGE.fetch(report.effective_status, "bg-slate-100 text-slate-600")
  end

  # Decorative today, same caveat as AgencyConnection#status_label — nothing
  # sets credential_status automatically yet (see admin-panel.md).
  def client_source_status_label(link)
    return "Not linked" if link.external_id.blank?
    return "Auth error" if link.credential_invalid?
    return "Expired" if link.credential_expired?
    return "Key expiring" if link.credential_expiring_soon?

    "Linked"
  end

  def client_source_status_dot_class(link)
    return "bg-slate-300" if link.external_id.blank?
    return "bg-red-500" if link.credential_invalid? || link.credential_expired?
    return "bg-amber-500" if link.credential_expiring_soon?

    "bg-emerald-500"
  end

  # HubSpot is the one source whose external_id drives onboarding_status/
  # onboarded_at/ai_seo_enrolled (see SyncClientFromHubspot), so it gets its
  # own status label distinct from the other data sources' "Linked".
  def hubspot_sync_status_label(link)
    return "Not linked" if link.nil? || link.external_id.blank?
    return "Sync failed" if link.last_sync_error.present?
    return "Synced #{time_ago_in_words(link.last_synced_at)} ago" if link.last_synced_at.present?

    "Syncing…"
  end

  def hubspot_sync_status_dot_class(link)
    return "bg-slate-300" if link.nil? || link.external_id.blank?
    return "bg-red-500" if link.last_sync_error.present?
    return "bg-emerald-500" if link.last_synced_at.present?

    "bg-amber-500"
  end

  # Adapters::Base's rescue wraps the raw Faraday::Error message (HTTP
  # status, URL, etc.) — accurate for a developer, meaningless to the admin
  # reading this on a client's page, so translate the common cases in plain
  # language and fall back to one generic line for anything else.
  HUBSPOT_SYNC_ERROR_MESSAGES = {
    /no credentials configured/i => "HubSpot isn't connected yet — add the agency-wide credentials in Connections.",
    /no company id configured/i => "No HubSpot company ID set for this practice yet.",
    /status 404/ => "HubSpot company ID not found — double-check the ID.",
    /status 401|status 403/ => "HubSpot rejected the request — the connected account may not have access.",
    /timeout/i => "HubSpot didn't respond in time — try again shortly.",
    /connection failed/i => "Couldn't reach HubSpot — try again shortly."
  }.freeze

  def hubspot_sync_error_message(link)
    error = link&.last_sync_error
    return nil if error.blank?

    _, message = HUBSPOT_SYNC_ERROR_MESSAGES.find { |pattern, _| pattern.match?(error) }
    message || "HubSpot sync failed — try again, or check the company ID."
  end

  private

  def first_report_badge?(report)
    report.is_first_report? && %w[sent ready].include?(report.effective_status)
  end
end
