# Thin wrapper around ReportGenerator so it can run on Solid Queue. Not yet
# wired into config/recurring.yml — SOW #6 leaves the exact monthly send date
# undecided, so this is enqueued manually / from an admin action for now.
#
# IDs in, not objects (CONVENTIONS #14) — keeps the job payload serializable
# and safe to retry after a deploy. Idempotent via ReportGenerator itself, so
# a retry after a partial failure is always safe to re-run.
class GenerateMonthlyReportJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(client_id, year, month)
    client = Client.find(client_id)
    ReportGenerator.new(client: client, month: Date.new(year, month, 1)).call
  end
end
