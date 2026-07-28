# frozen_string_literal: true

class ReportKeywordRanking < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
  belongs_to :keyword, class_name: "ClientKeyword"

  # Validations
  validates :keyword_id, uniqueness: { scope: :report_id }
end
