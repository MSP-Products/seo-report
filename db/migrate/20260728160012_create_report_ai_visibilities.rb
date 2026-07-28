# frozen_string_literal: true

class CreateReportAiVisibilities < ActiveRecord::Migration[8.1]
  def change
    create_table :report_ai_visibilities do |t|
      t.string :report_id, limit: 36, null: false
      t.integer :overall_score
      t.integer :previous_score
      t.integer :google_rank
      t.integer :ai_rank
      t.integer :sentiment_positive_pct
      t.integer :sentiment_neutral_pct
      t.integer :sentiment_negative_pct
      t.integer :citation_own_site_pct
      t.integer :citation_listings_pct
      t.integer :citation_reputation_pct
      t.integer :citation_third_party_pct
    end

    add_foreign_key :report_ai_visibilities, :monthly_reports, column: :report_id
    add_index :report_ai_visibilities, :report_id, unique: true
  end
end
