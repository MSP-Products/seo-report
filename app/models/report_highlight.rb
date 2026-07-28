# frozen_string_literal: true

class ReportHighlight < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
end
