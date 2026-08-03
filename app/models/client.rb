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
      r.is_first_report = monthly_reports.where("report_month < ?", month).none?
    end
  end
end
