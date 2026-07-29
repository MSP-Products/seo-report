# frozen_string_literal: true

class ReportTraffic < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"

  # Enums
  enum :ghl_data_status, {
    connected: "connected",
    not_connected: "not_connected",
    access_unavailable: "access_unavailable"
  }, validate: true
end
