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

  # Enums
  enum :generation_status, { queued: "queued", generating: "generating", ready: "ready", failed: "failed" },
    validate: true

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

  # Wall-clock start of this month's run — every report for the month is
  # created "queued" at once by EnqueueMonthlyReportsJob, so the earliest
  # created_at is the run's start time.
  def self.run_started_at(month)
    where(report_month: month).minimum(:created_at)
  end

  def self.currently_generating_client(month)
    where(report_month: month).generating.first&.client
  end

  private

  def generate_access_token
    self.access_token ||= SecureRandom.urlsafe_base64(32)
  end
end
