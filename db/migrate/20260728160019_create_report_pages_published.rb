# frozen_string_literal: true

class CreateReportPagesPublished < ActiveRecord::Migration[8.1]
  def change
    create_table :report_pages_published do |t|
      t.string :report_id, limit: 36, null: false
      t.references :sitemap_page, type: :bigint, null: false, foreign_key: true
      t.string :url
      t.string :title
      t.text :description
    end

    add_foreign_key :report_pages_published, :monthly_reports, column: :report_id
  end
end
