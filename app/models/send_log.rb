# frozen_string_literal: true

class SendLog < ApplicationRecord
  # Associations
  belongs_to :monthly_report

  # Enums
  # held: blocked on something recoverable (e.g. the destination credential
  # was rejected) — distinct from failed, which is not expected to resolve
  # itself on a plain retry.
  enum :status, { success: "success", failed: "failed", held: "held" }, validate: true

  # Validations
  validates :attempted_at, presence: true

  # Scopes
  scope :latest_first, -> { order(attempted_at: :desc) }
end
