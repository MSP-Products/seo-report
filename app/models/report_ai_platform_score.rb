# frozen_string_literal: true

class ReportAiPlatformScore < ApplicationRecord
  # Associations
  belongs_to :report_ai_visibility

  # Enums
  enum :platform, {
    chatgpt: "chatgpt",
    google_ai_overview: "google_ai_overview",
    ai_mode: "ai_mode",
    gemini: "gemini"
  }, validate: true
end
