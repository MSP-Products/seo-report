# frozen_string_literal: true

class MonthlyReport < ApplicationRecord
  include HasUuidPrimaryKey

  # Associations
  belongs_to :client
  has_many :report_generation_logs, dependent: :destroy
  has_many :send_logs, dependent: :destroy
  has_one :report_highlight, foreign_key: :report_id, dependent: :destroy
  has_one :report_traffic, foreign_key: :report_id, dependent: :destroy
  has_one :report_citation, foreign_key: :report_id, dependent: :destroy
  has_one :report_ai_visibility, foreign_key: :report_id, dependent: :destroy
  has_one :report_gbp_summary, foreign_key: :report_id, dependent: :destroy
  has_many :report_keyword_rankings, foreign_key: :report_id, dependent: :destroy
  has_many :gbp_posts, foreign_key: :report_id, dependent: :destroy
  has_many :gbp_reviews, foreign_key: :report_id, dependent: :destroy
  has_many :gbp_photos, foreign_key: :report_id, dependent: :destroy
  has_many :report_pages_published, class_name: "ReportPagePublished", foreign_key: :report_id, dependent: :destroy

  # Validations
  validates :report_month, presence: true
  validates :report_month, uniqueness: { scope: :client_id }
  validates :access_token, presence: true, uniqueness: true

  # Scopes
  scope :for_month, ->(year, month) { where(report_month: Date.new(year, month, 1)) }
  scope :generated, -> { where.not(generated_at: nil) }
  scope :not_emailed, -> { where(emailed_at: nil) }

  # Callbacks
  before_validation :generate_access_token, on: :create

  private

  def generate_access_token
    self.access_token ||= SecureRandom.urlsafe_base64(32)
  end
end
