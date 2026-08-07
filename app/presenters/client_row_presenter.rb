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

  def service_links
    @service_links ||= Service::KEYS.index_with do |service|
      client.client_service_links.find { |link| link.service == service }
    end
  end

  def service_link(service)
    service_links[service]
  end

  def hubspot_link
    service_link("hubspot")
  end

  # Short form for the index's tight grid column — shows all service statuses
  def service_status_labels
    @service_status_labels ||= Service::KEYS.map do |service|
      link = service_link(service)
      label = if link.nil? || link.external_id.blank?
                "Not linked"
              elsif link.last_sync_error.present?
                "Failed"
              elsif link.last_synced_at.present?
                "Linked"
              else
                "Syncing…"
              end

      { service: service, label: label, link: link }
    end
  end

  def hubspot_sync_label
    hubspot_status = service_status_labels.find { |s| s[:service] == "hubspot" }
    hubspot_status[:label]
  end

  def delivery_label
    return "Stopped" if client.offboarded?
    return "Setup complete" if latest_report.nil?
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
