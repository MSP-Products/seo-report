# frozen_string_literal: true

class CreateMonthlyReports < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_reports, id: false do |t|
      t.string :id, limit: 36, primary_key: true, default: -> { "(UUID())" }
      t.string :client_id, limit: 36, null: false
      t.date :report_month, null: false
      t.boolean :is_first_report, default: false
      t.string :access_token, null: false
      t.datetime :generated_at
      t.datetime :emailed_at

      t.timestamps
    end

    add_foreign_key :monthly_reports, :clients
    add_index :monthly_reports, :access_token, unique: true
    add_index :monthly_reports, [ :client_id, :report_month ], unique: true
  end
end
