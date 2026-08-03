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

  # Validations
  validates :name, presence: true

  # Scopes
  scope :with_ai_seo, -> { where(ai_seo_enrolled: true) }

  # Shared by EnqueueMonthlyReportsJob (creates it queued, ahead of actually
  # running) and ReportGenerator (finds the same row when the job runs) —
  # one place decides is_first_report so it's never computed twice.
  def find_or_create_monthly_report(month)
    monthly_reports.find_or_create_by!(report_month: month) do |r|
      r.is_first_report = first_report_month?(month)
    end
  end

  private

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
