# frozen_string_literal: true

class GbpReview < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"

  # Enums
  enum :sentiment, {
    positive: "positive",
    neutral: "neutral",
    negative: "negative"
  }, validate: true

  # Validations
  validates :external_id, uniqueness: { scope: :report_id }, allow_nil: true

  # Scopes
  scope :needs_action, -> { where(needs_action: true) }
end
