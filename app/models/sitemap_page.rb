# frozen_string_literal: true

class SitemapPage < ApplicationRecord
  # Associations
  belongs_to :client
  has_many :report_pages_published, class_name: "ReportPagePublished", dependent: :destroy

  # Validations
  validates :url, presence: true
  validates :url, uniqueness: { scope: :client_id }
end
