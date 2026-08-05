# frozen_string_literal: true

class ReportTraffic < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"

  # Enums
  #
  # Only two values now — a client either has no GHL link ("not_connected")
  # or a working one ("connected"). There used to be a third,
  # "access_unavailable", for a linked-but-failing GHL call, back when
  # ReportGenerator degraded that into a placeholder; a linked GHL client is
  # now mandatory, so that call failing raises and aborts the whole report
  # instead of ever reaching this column. See ReportGenerator#sync_traffic.
  enum :ghl_data_status, {
    connected: "connected",
    not_connected: "not_connected"
  }, validate: true
end
