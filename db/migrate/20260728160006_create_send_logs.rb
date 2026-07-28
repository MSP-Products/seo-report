# frozen_string_literal: true

class CreateSendLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :send_logs do |t|
      t.string :monthly_report_id, limit: 36, null: false
      t.datetime :attempted_at, null: false
      t.string :status, null: false
      t.text :error_message
    end

    add_foreign_key :send_logs, :monthly_reports
  end
end
