module Adapters
  # Every adapter's #call returns one of these instead of raising, so
  # ReportGenerator can log a per-service failure and keep generating the
  # rest of the report.
  Result = Data.define(:success?, :data, :error, :not_found) do
    def self.success(data = {})
      new(success?: true, data: data, error: nil, not_found: false)
    end

    # not_found: the remote record itself is gone (HTTP 404) — a permanent
    # signal, unlike a timeout or 5xx, that callers may want to treat
    # differently from an ordinary transient failure.
    def self.failure(error, not_found: false)
      new(success?: false, data: nil, error: error, not_found: not_found)
    end
  end
end
