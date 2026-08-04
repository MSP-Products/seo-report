# Filtered, paginated read for the Clients roster — search + status filter + counts
# across Client and its associations, too much for a plain scope.
class ClientsQuery
  PER_PAGE = 10
  STATUSES = %w[active pending offboarded].freeze

  # total_count/active_count/pending_count are always unfiltered (the pill labels always
  # show the full roster's counts, independent of the currently applied search/status).
  # filtered_count reflects the current search+status filter, for pagination.
  Result = Data.define(:clients, :total_count, :active_count, :pending_count, :filtered_count, :page, :total_pages)

  def initialize(search: nil, status: nil, page: 1)
    @search = search.presence
    @status = status.presence if STATUSES.include?(status.to_s)
    @page = page.to_i.clamp(1, Float::INFINITY)
  end

  def call
    Result.new(
      clients: filtered_scope.order(:name).limit(PER_PAGE).offset((page - 1) * PER_PAGE),
      total_count: Client.kept.count,
      active_count: Client.kept.active.count,
      pending_count: Client.kept.pending.count,
      filtered_count: filtered_count,
      page: page,
      total_pages: (filtered_count / PER_PAGE.to_f).ceil
    )
  end

  private

  attr_reader :search, :status, :page

  def filtered_scope
    relation = status ? Client.kept.public_send(status) : Client.kept
    relation = relation.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(search)}%") if search
    relation.includes(:client_service_links, monthly_reports: :report_generation_logs)
  end

  def filtered_count
    @filtered_count ||= filtered_scope.count
  end
end
