# Per-row display logic for the Clients index (avatar initials, delivery
# status, enrollment tags) — kept off the view per CONVENTIONS.md #11.
# Expects client.monthly_reports and client.client_service_links to already
# be preloaded by ClientsController#index; every method here reads the
# loaded association in memory, never issues its own query.
class ClientRowPresenter
  DELIVERY_DOT = {
    "sent" => "bg-emerald-500", "ready" => "bg-teal-primary", "held" => "bg-amber-500",
    "queued" => "bg-amber-500", "generating" => "bg-amber-500", "failed" => "bg-red-500"
  }.freeze

  delegate :name, :website_url, :onboarding_status, to: :client

  def initialize(client)
    @client = client
  end

  def initials
    name.split(/\s+/).first(2).map { |word| word[0] }.join.upcase
  end

  def report_count
    client.monthly_reports.size
  end

  def latest_report
    @latest_report ||= client.monthly_reports.max_by(&:report_month)
  end

  def latest_report_label
    latest_report&.report_month&.strftime("%B %Y") || "Not yet"
  end

  def latest_report_sublabel
    return "No reports yet" if latest_report.nil?

    "#{report_count} #{"report".pluralize(report_count)}"
  end

  def scheduler_enabled?
    client.client_service_links.any? { |link| link.service == "ghl" }
  end

  def ai_seo_enrolled?
    client.ai_seo_enrolled?
  end

  def hubspot_link
    client.hubspot_link
  end

  # Short form for the index's tight grid column — the detail edit page
  # shows the full "Synced 3 minutes ago" via ClientsHelper#hubspot_sync_status_label.
  def hubspot_sync_label
    return "Not linked" if hubspot_link.nil? || hubspot_link.external_id.blank?
    return "Sync failed" if hubspot_link.last_sync_error.present?
    return "Synced" if hubspot_link.last_synced_at.present?

    "Syncing…"
  end

  def delivery_label
    return "Stopped" if client.offboarded?
    return "Waiting" if latest_report.nil?
    return "Failed ×#{latest_report.attempt_count}" if latest_report.effective_status == "failed" && latest_report.attempt_count > 1

    latest_report.effective_status.capitalize
  end

  def delivery_dot_class
    return "bg-slate-300" if client.offboarded? || latest_report.nil?

    DELIVERY_DOT.fetch(latest_report.effective_status, "bg-slate-300")
  end

  private

  attr_reader :client
end
