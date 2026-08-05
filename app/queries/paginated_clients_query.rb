# frozen_string_literal: true

# The Clients index's pagination — a read too complex for a bare scope
# (needs a count, a clamped page number, and a limit/offset), so it earns
# app/queries/ per CLAUDE.md's extraction ladder. Scoped to Clients only;
# generalize into a shared paginator only if a second index page needs one
# (rule of three).
class PaginatedClientsQuery
  PER_PAGE = 20

  def initialize(scope, page:)
    @scope = scope
    @requested_page = page
  end

  def records
    @scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE)
  end

  def page
    @page ||= [ [ @requested_page.to_i, 1 ].max, total_pages ].min
  end

  def total_pages
    @total_pages ||= [ (total_count / PER_PAGE.to_f).ceil, 1 ].max
  end

  def total_count
    @total_count ||= @scope.count
  end
end
