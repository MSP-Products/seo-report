# frozen_string_literal: true

class Client < ApplicationRecord
  include Discard::Model

  # Enums
  enum :onboarding_status, { pending: "pending", active: "active", offboarded: "offboarded" }, validate: true
  enum :page_scan_method, { sitemap: "sitemap", crawler: "crawler", failed_scan: "failed" }, validate: true
  enum :last_page_scan_status, { scan_success: "success", scan_failed: "failed" }, validate: true

  # Associations
  has_many :client_service_links, dependent: :destroy
  has_many :monthly_reports, dependent: :destroy
  has_many :client_keywords, dependent: :destroy
  has_many :sitemap_pages, dependent: :destroy

  # Validations
  validates :name, presence: true

  # Scopes
  scope :with_ai_seo, -> { where(ai_seo_enrolled: true) }
end
