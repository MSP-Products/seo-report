# frozen_string_literal: true

class ReportAiPlatformScore < ApplicationRecord
  # Associations
  belongs_to :report_ai_visibility

  # Not an enum: Yext's real AI_MODEL values (e.g. "gemini", "perplexity")
  # don't match a fixed list we control, and new models can appear over time —
  # store whatever the adapter returns directly instead of whitelisting it.
  validates :platform, presence: true
end
