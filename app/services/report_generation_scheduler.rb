# Enqueues GenerateMonthlyReportJob for the current reporting month — either one
# client (an explicit retry) or every active client missing a completed report
# yet (the Dashboard's bulk "Run reports" action).
class ReportGenerationScheduler
  def initialize(client_id: nil)
    @client_id = client_id
  end

  def call
    clients_to_run.each { |client| GenerateMonthlyReportJob.perform_later(client.id, month.year, month.month) }
  end

  private

  attr_reader :client_id

  def month
    @month ||= MonthlyReport.reporting_month
  end

  def clients_to_run
    return [ Client.kept.find(client_id) ] if client_id.present?

    Client.kept.active.reject { |client| completed_report_this_month?(client) }
  end

  def completed_report_this_month?(client)
    client.monthly_reports.where(report_month: month).where.not(generated_at: nil).exists?
  end
end
