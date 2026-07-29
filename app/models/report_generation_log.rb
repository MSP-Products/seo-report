# frozen_string_literal: true

class ReportGenerationLog < ApplicationRecord
  # Associations
  belongs_to :monthly_report

  # Enums
  enum :status, { success: "success", failed: "failed" }, validate: true

  # Validations
  validates :attempted_at, presence: true

  # Scopes
  scope :latest_first, -> { order(attempted_at: :desc) }
end
