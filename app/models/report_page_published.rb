# frozen_string_literal: true

class ReportPagePublished < ApplicationRecord
  # "report_pages_published" doesn't inflect back from ReportPagePublished by
  # Rails' standard tableize rules (it would guess "report_page_publisheds").
  self.table_name = "report_pages_published"

  # Associations
  belongs_to :report, class_name: "MonthlyReport"
  belongs_to :sitemap_page
end
