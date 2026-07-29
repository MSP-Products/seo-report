# frozen_string_literal: true

class CreateReportTraffics < ActiveRecord::Migration[8.1]
  def change
    create_table :report_traffics do |t|
      t.string :report_id, limit: 36, null: false
      t.integer :total_visits
      t.integer :previous_total_visits
      t.integer :unique_visitors
      t.decimal :pages_per_visit, precision: 8, scale: 2
      t.integer :organic_visits
      t.integer :previous_organic_visits
      t.integer :direct_visits
      t.integer :previous_direct_visits
      t.integer :referral_visits
      t.integer :previous_referral_visits
      t.integer :paid_visits
      t.integer :previous_paid_visits
      t.integer :appointments_booked
      t.integer :previous_appointments_booked
      t.decimal :estimated_revenue, precision: 12, scale: 2
      t.decimal :previous_estimated_revenue, precision: 12, scale: 2
      t.string :ghl_data_status
    end

    add_foreign_key :report_traffics, :monthly_reports, column: :report_id
    add_index :report_traffics, :report_id, unique: true
  end
end
