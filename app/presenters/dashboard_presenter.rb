# Wraps the current reporting cycle for the Dashboard: client counts, this
# month's generation run, and per-service connection health. Keeps the
# elapsed-time arithmetic and DB access out of the view.
class DashboardPresenter
  def initialize(month: Date.current.beginning_of_month - 1.month)
    @month = month
  end

  attr_reader :month

  def month_label
    month.strftime("%B %Y")
  end

  def client_count
    Client.kept.count
  end

  def active_client_count
    Client.kept.active.count
  end

  def pending_client_count
    Client.kept.pending.count
  end

  def reports
    @reports ||= MonthlyReport.where(report_month: month).includes(:client, :send_logs).order(:created_at)
  end

  # Every active client for the cycle, paired with their report — nil when a
  # client has no row yet, so a client the run hasn't picked up (never
  # enqueued, or added after the run started) is still visible rather than
  # silently missing from the table.
  def report_rows
    @report_rows ||= begin
      reports_by_client_id = reports.index_by(&:client_id)
      started = reports.map { |report| { client: report.client, report: report } }
      not_started = Client.kept.active.order(:name)
        .reject { |client| reports_by_client_id.key?(client.id) }
        .map { |client| { client: client, report: nil } }

      started + not_started
    end
  end

  # The run hasn't started generating this cycle's reports yet if there's no
  # row for the month at all — distinct from every client already being ready.
  def run_started?
    reports.any?
  end

  def total_expected
    active_client_count
  end

  def ready_count
    reports.ready.count
  end

  def failed_count
    reports.failed.count
  end

  def run_in_progress?
    reports.queued.exists? || reports.generating.exists?
  end

  def currently_generating_client
    MonthlyReport.currently_generating_client(month)
  end

  def run_started_at
    MonthlyReport.run_started_at(month)
  end

  def elapsed
    return nil unless run_started_at

    Time.current - run_started_at
  end

  def progress_percent
    return 0 if total_expected.zero?

    ((ready_count.to_f / total_expected) * 100).round
  end

  # Average wall-clock time from mark_generating to mark_ready, across this
  # cycle's ready reports — how long generating one report actually takes,
  # not to be confused with elapsed (how long the whole run has been going).
  def average_generation_time
    durations = reports.ready.where.not(generation_started_at: nil).filter_map do |report|
      report.generated_at - report.generation_started_at
    end
    return nil if durations.empty?

    durations.sum / durations.size
  end

  def sent_count
    reports.where.not(emailed_at: nil).count
  end

  def held_count
    SendLog.held.where(monthly_report_id: reports.select(:id)).count
  end

  def connections
    AgencyConnection.all_services
  end
end
