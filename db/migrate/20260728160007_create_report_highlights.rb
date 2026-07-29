# frozen_string_literal: true

class CreateReportHighlights < ActiveRecord::Migration[8.1]
  def change
    create_table :report_highlights do |t|
      t.string :report_id, limit: 36, null: false
      t.text :summary_text
      t.text :ai_seo_summary_text
      t.datetime :generated_at
      t.string :model_used
    end

    add_foreign_key :report_highlights, :monthly_reports, column: :report_id
    add_index :report_highlights, :report_id, unique: true
  end
end
