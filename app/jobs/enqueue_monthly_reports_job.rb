# Fans out one GenerateMonthlyReportJob per active client for the last
# completed month. Scheduled in config/recurring.yml for the 1st of every
# month — SOW #6 leaves the exact send date open, but generation itself
# runs on a fixed monthly cadence.
class EnqueueMonthlyReportsJob < ApplicationJob
  queue_as :default

  def perform
    month = Date.current.beginning_of_month - 1.month

    Client.kept.active.find_each do |client|
      next if client.monthly_reports.generated.exists?(report_month: month)

      GenerateMonthlyReportJob.perform_later(client.id, month.year, month.month)
    end
  end
end
