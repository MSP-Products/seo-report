# frozen_string_literal: true

class ReportAiVisibility < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
  has_many :report_ai_platform_scores, dependent: :destroy
end
