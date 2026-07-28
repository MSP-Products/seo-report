# frozen_string_literal: true

class CreateReportGenerationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :report_generation_logs do |t|
      t.string :monthly_report_id, limit: 36, null: false
      t.datetime :attempted_at, null: false
      t.string :status, null: false
      t.string :error_summary
      t.text :error_log
    end

    add_foreign_key :report_generation_logs, :monthly_reports
    add_index :report_generation_logs, [ :monthly_report_id, :attempted_at ], name: "idx_report_gen_logs_on_report_and_attempted"
  end
end
