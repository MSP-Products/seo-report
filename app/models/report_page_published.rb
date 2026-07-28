# frozen_string_literal: true

class ReportPagePublished < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
  belongs_to :sitemap_page
end
