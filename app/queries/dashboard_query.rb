# Aggregates the data the admin Dashboard shows: this reporting cycle's status
# per active client, generated/failed counts, average generation time, and
# integration health — a read across Client/MonthlyReport/ReportGenerationLog/
# AgencyConnection too cross-cutting for any one model's scope.
class DashboardQuery
  Result = Data.define(
    :report_month, :client_rows, :generated_count, :failed_count,
    :pending_onboarding_count, :avg_duration_seconds, :connections, :attention_count
  )
  ClientRow = Data.define(:client, :report, :latest_log, :status)

  def initialize(report_month: MonthlyReport.reporting_month)
    @report_month = report_month
  end

  def call
    Result.new(
      report_month: report_month,
      client_rows: client_rows,
      generated_count: client_rows.count { |row| row.status == :generated },
      failed_count: client_rows.count { |row| row.status == :failed },
      pending_onboarding_count: Client.kept.pending.count,
      avg_duration_seconds: ReportGenerationLog.where(status: "success").average(:duration_seconds)&.round,
      connections: connections,
      attention_count: connections.count { |connection| !connection.credential_active? }
    )
  end

  private

  attr_reader :report_month

  def client_rows
    @client_rows ||= active_clients.map do |client|
      report = reports_by_client_id[client.id]
      latest_log = report&.report_generation_logs&.max_by(&:attempted_at)

      ClientRow.new(client: client, report: report, latest_log: latest_log,
        status: report&.generation_status || :not_yet_generated)
    end
  end

  def active_clients
    @active_clients ||= Client.kept.active.order(:name)
  end

  def reports_by_client_id
    @reports_by_client_id ||= MonthlyReport
      .for_month(report_month.year, report_month.month)
      .where(client_id: active_clients.map(&:id))
      .includes(:report_generation_logs)
      .index_by(&:client_id)
  end

  def connections
    @connections ||= AgencyConnection.all_services
  end
end
