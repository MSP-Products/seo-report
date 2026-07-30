module Adapters
  # Every adapter's #call returns one of these instead of raising, so
  # ReportGenerator can log a per-service failure and keep generating the
  # rest of the report.
  Result = Data.define(:success?, :data, :error) do
    def self.success(data = {})
      new(success?: true, data: data, error: nil)
    end

    def self.failure(error)
      new(success?: false, data: nil, error: error)
    end
  end
end
