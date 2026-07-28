# frozen_string_literal: true

class CreateReportKeywordRankings < ActiveRecord::Migration[8.1]
  def change
    create_table :report_keyword_rankings do |t|
      t.string :report_id, limit: 36, null: false
      t.references :keyword, type: :bigint, null: false, foreign_key: { to_table: :client_keywords }
      t.integer :position
      t.integer :previous_position
      t.decimal :potential_traffic, precision: 10, scale: 2
      t.decimal :growth, precision: 10, scale: 2
    end

    add_foreign_key :report_keyword_rankings, :monthly_reports, column: :report_id
    add_index :report_keyword_rankings, [ :report_id, :keyword_id ], unique: true
  end
end
