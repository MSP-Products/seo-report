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

  # The public report's one preload list — every association a report
  # section reads. Add a new section's association here, or it N+1s on the
  # one page clients actually load.
  scope :for_public_view, -> {
    includes(
      :client,
      :report_highlight,
      :report_traffic,
      :report_citation,
      :report_gbp_summary,
      :gbp_posts,
      :gbp_reviews,
      :gbp_photos,
      :report_pages_published,
      report_ai_visibility: :report_ai_platform_scores,
      report_keyword_rankings: :keyword
    )
  }

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

  # For the admin Report Log page — newest cycle first, then newest
  # attempt within it. Scoped to one month when given, otherwise every month.
  def self.for_report_log(month: nil)
    scope = includes(:client, :send_logs).order(report_month: :desc, created_at: :desc)
    month ? scope.where(report_month: month) : scope
  end

  def self.parse_month_param(value)
    Date.strptime(value, "%Y-%m")
  rescue ArgumentError, TypeError
    nil
  end

  # One filterable status per report, folding send state into generation
  # state — "sent"/"held" only mean anything once a report is ready, so a
  # ready report is never double-counted under both "ready" and "sent".
  EFFECTIVE_STATUSES = %w[queued generating ready sent held failed].freeze

  def effective_status
    return generation_status unless ready?
    return "sent" if emailed_at.present?
    return "held" if send_logs.any?(&:held?)

    "ready"
  end

  private

  def generate_access_token
    self.access_token ||= SecureRandom.urlsafe_base64(32)
  end
end
