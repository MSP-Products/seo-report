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

  # address is one free-text field ("123 Oak St, San Francisco, CA 94102") — this
  # pulls out "San Francisco, CA" for compact display (e.g. the Dashboard table).
  def city_state
    parts = address.to_s.split(",").map(&:strip)
    return address if parts.size < 3

    "#{parts[-2]}, #{parts[-1].sub(/\s*\d{5}(-\d{4})?\z/, "")}"
  end

  # GHL is the agency's appointment-scheduler integration — a link to it *is* the
  # "uses our scheduler" signal, there's no separate flag (see docs/features/integration-ghl.md).
  def scheduler_enrolled?
    client_service_links.any? { |link| link.service == "ghl" }
  end

  def latest_monthly_report
    monthly_reports.max_by(&:report_month)
  end
end
