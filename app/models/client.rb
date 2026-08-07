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

  # Set by ClientsController#destroy/#restore before their save — offboarding
  # and restoring are explicit admin overrides of onboarding_status, and
  # without this, #sync_linked_services would immediately re-trigger the
  # HubSpot sync and could clobber that override in the same request (e.g. a
  # HubSpot company that's genuinely still active would undiscard and
  # reactivate a practice the instant it was offboarded). The existing hourly
  # EnqueueHubspotSyncJob still reconciles within the hour either way.
  attr_accessor :skip_service_sync

  # A HubSpot company ID means the sync (triggered right after this saves,
  # see #sync_linked_services) is about to fill in name, address, and
  # website_url — so don't force an admin to type a name by hand just to
  # satisfy this validation before that happens.
  before_validation :set_placeholder_name_for_hubspot_sync

  after_commit :sync_linked_services

  # Validations
  validates :name, presence: true, unless: :syncing_from_hubspot?

  # Scopes
  scope :with_ai_seo, -> { where(ai_seo_enrolled: true) }
  scope :search, ->(q) { where("name ILIKE ?", "%#{sanitize_sql_like(q)}%") if q.present? }
  scope :by_status, ->(status) { where(onboarding_status: status) if status.present? }

  # Counts behind the Clients index's status tabs, keyed by tab ("all" plus each
  # onboarding_status). Lives here rather than in the view because CLAUDE.md
  # forbids DB queries in ERB, and it folds what were five separate count
  # queries into two.
  #
  # "offboarded" counts *discarded* rows: offboarding soft-deletes, so those
  # practices are outside the kept scope the other tabs read from.
  def self.status_counts(query)
    kept_by_status = kept.search(query).group(:onboarding_status).count
    discarded_count = discarded.search(query).count

    counts = onboarding_statuses.keys.index_with do |status|
      status == "offboarded" ? discarded_count : kept_by_status.fetch(status, 0)
    end

    counts.merge("all" => kept_by_status.values.sum + discarded_count)
  end

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

  # Linked and currently healthy — distinct from syncing_from_hubspot?, which
  # only checks a company ID is set. A link with a company ID but a standing
  # last_sync_error (e.g. a 404 on a deleted company) is not "successfully"
  # linked, so the practice-details fields it would otherwise overwrite must
  # stay editable by hand until the link is fixed.
  def hubspot_synced?
    hubspot_link&.external_id.present? && hubspot_link.last_sync_error.blank?
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

  # Re-verifies every service this practice is linked to on every save —
  # not gated on which field changed, since one form submission can touch
  # several links' external_id at once (accepts_nested_attributes_for), and
  # a stale result on an untouched link is still worth refreshing. HubSpot
  # gets its full sync (name/address/website/onboarding state, not just
  # connectivity); every other linked service gets
  # LinkedServiceConnectionTester's lightweight connection check.
  #
  # HubSpot's job runs even with a blank external_id — a cleared HubSpot ID
  # still needs SyncClientFromHubspot#fetch_result's "not connected" guard to
  # normalize onboarding_status (pending if kept, offboarded if discarded),
  # unlike the other four services, which have nothing to check with no ID
  # at all.
  def sync_linked_services
    return if skip_service_sync

    client_service_links.each do |link|
      next if link.external_id.blank? && !link.hubspot?

      link.hubspot? ? SyncHubspotClientJob.perform_later(id) : TestClientServiceConnectionJob.perform_later(link.id)
    end
  end

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
