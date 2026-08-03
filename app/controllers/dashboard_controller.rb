class DashboardController < ApplicationController
  def index
    @clients = ClientsController::CLIENTS.first(5)

    @connections = [
      { name: "SEMrush", dot: "red" },
      { name: "Yext", dot: "red" },
      { name: "Google Analytics", dot: "yellow" },
      { name: "GoHighLevel", dot: "purple" },
      { name: "HubSpot", dot: "red" }
    ]

    counts = { sent: 32, ready: 0, pending: 5, failed: 4 }
    total = counts.values.sum
    @progress_counts = counts
    @progress_percents = counts.transform_values { |v| total.zero? ? 0 : (v.to_f / total * 100).round(1) }
    @total_expected = 47
  end
end