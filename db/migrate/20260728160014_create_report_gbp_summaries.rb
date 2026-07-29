# frozen_string_literal: true

class CreateReportGbpSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :report_gbp_summaries do |t|
      t.string :report_id, limit: 36, null: false
      t.integer :total_reviews
      t.decimal :average_rating, precision: 3, scale: 2
      t.integer :new_positive_reviews
      t.integer :new_negative_reviews
      t.boolean :needs_photos, default: false
    end

    add_foreign_key :report_gbp_summaries, :monthly_reports, column: :report_id
    add_index :report_gbp_summaries, :report_id, unique: true
  end
end
