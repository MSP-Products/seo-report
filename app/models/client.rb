# frozen_string_literal: true

class Client < ApplicationRecord
  include Discard::Model
  include HasUuidPrimaryKey

  # Enums
  enum :onboarding_status, { pending: "pending", active: "active", offboarded: "offboarded" }, validate: true
  # allow_nil: a client has no scan method/status until its first sitemap/crawler run
  enum :page_scan_method, { sitemap: "sitemap", crawler: "crawler", failed: "failed" },
    prefix: :page_scan, validate: { allow_nil: true }
  enum :last_page_scan_status, { success: "success", failed: "failed" },
    prefix: :last_page_scan, validate: { allow_nil: true }

  # Associations
  has_many :client_service_links, dependent: :destroy
  has_many :monthly_reports, dependent: :destroy
  has_many :client_keywords, dependent: :destroy
  has_many :sitemap_pages, dependent: :destroy
  accepts_nested_attributes_for :client_service_links

  # A HubSpot company ID means the sync (triggered right after this saves,
  # see ClientServiceLink#enqueue_hubspot_sync) is about to fill in name,
  # address, and website_url — so don't force an admin to type a name by
  # hand just to satisfy this validation before that happens.
  before_validation :set_placeholder_name_for_hubspot_sync

  # Validations
  validates :name, presence: true, unless: :syncing_from_hubspot?

  # Scopes
  scope :with_ai_seo, -> { where(ai_seo_enrolled: true) }
  scope :search, ->(q) { where("name ILIKE ?", "%#{sanitize_sql_like(q)}%") if q.present? }
  scope :by_status, ->(status) { where(onboarding_status: status) if status.present? }

  # One row per known service, in the Edit practice form — existing links
  # for the ones already linked, an unsaved stub for the rest, so every
  # service always has an input to fill in.
  def service_links_for_form
    Service::KEYS.map do |service|
      client_service_links.find { |link| link.service == service } ||
        client_service_links.build(service: service)
    end
  end

  def online_scheduler_connected?
    client_service_links.any? { |link| link.service == "ghl" && link.external_id.present? }
  end

  def hubspot_link
    client_service_links.find { |link| link.service == "hubspot" }
  end

  # Shared by EnqueueMonthlyReportsJob (creates it queued, ahead of actually
  # running) and ReportGenerator (finds the same row when the job runs) —
  # one place decides is_first_report so it's never computed twice.
  def find_or_create_monthly_report(month)
    monthly_reports.find_or_create_by!(report_month: month) do |r|
      r.is_first_report = first_report_month?(month)
    end
  end

  private

  def syncing_from_hubspot?
    hubspot_link&.external_id.present?
  end

  def set_placeholder_name_for_hubspot_sync
    return if name.present? || !syncing_from_hubspot?

    self.name = "Syncing from HubSpot…"
  end

  # Per SOW #9, HubSpot's onboarding date (onboarded_at, synced from
  # gmb_seo_start_date — confirmed with MSP) is the source of truth for which
  # month is a client's first report, not "have we ever generated one
  # before". That distinction matters for a backfilled client: onboarded_at
  # correctly identifies their real first month even if generation only
  # started running for them later. Falls back to the report-history
  # heuristic when onboarded_at isn't known yet (e.g. not yet synced from
  # HubSpot at all).
  def first_report_month?(month)
    return onboarded_at.beginning_of_month == month if onboarded_at.present?

    monthly_reports.where("report_month < ?", month).none?
  end
end
