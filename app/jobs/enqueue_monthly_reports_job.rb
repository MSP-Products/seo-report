# Fans out one GenerateMonthlyReportJob per active client for the last
# completed month. Scheduled in config/recurring.yml for the 1st of every
# month — SOW #6 leaves the exact send date open, but generation itself
# runs on a fixed monthly cadence.
#
# Creates each client's MonthlyReport row up front, queued, rather than
# waiting for GenerateMonthlyReportJob to run — so a dashboard can show the
# full "34 of 42" picture (and each client's queue position) the moment the
# run starts, not just once jobs begin executing.
class EnqueueMonthlyReportsJob < ApplicationJob
  queue_as :default

  def perform
    month = Date.current.beginning_of_month - 1.month
    enqueued_count = 0
    skipped_count = 0

    Client.kept.active.find_each do |client|
      report = client.find_or_create_monthly_report(month)

      if report.ready?
        skipped_count += 1
        next
      end

      GenerateMonthlyReportJob.perform_later(client.id, month.year, month.month)
      enqueued_count += 1
    end

    Rails.logger.info(
      "EnqueueMonthlyReportsJob: #{month.strftime("%B %Y")} — enqueued #{enqueued_count}, skipped #{skipped_count} (already generated)"
    )
  end
end
