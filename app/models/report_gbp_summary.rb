# frozen_string_literal: true

class ReportGbpSummary < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
end
