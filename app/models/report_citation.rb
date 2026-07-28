# frozen_string_literal: true

class ReportCitation < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
end
