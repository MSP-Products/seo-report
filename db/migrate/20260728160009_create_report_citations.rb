# frozen_string_literal: true

class CreateReportCitations < ActiveRecord::Migration[8.1]
  def change
    create_table :report_citations do |t|
      t.string :report_id, limit: 36, null: false
      t.integer :total_impressions
      t.integer :previous_impressions
      t.integer :total_engagements
      t.integer :previous_engagements
      t.integer :driving_directions_count
      t.integer :website_clicks_count
    end

    add_foreign_key :report_citations, :monthly_reports, column: :report_id
    add_index :report_citations, :report_id, unique: true
  end
end
