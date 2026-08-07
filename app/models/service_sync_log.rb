# frozen_string_literal: true

# Records how long each service takes to check during sync, success/failure status,
# and any errors — for accurate time estimates and debugging.
class ServiceSyncLog < ApplicationRecord
  belongs_to :client

  enum :status, { success: "success", not_found: "not_found", error: "error" }, suffix: true

  # Average duration for a service from the last 3-4 successful checks
  def self.average_duration_for(service)
    where(service: service, status: :success)
      .order(created_at: :desc)
      .limit(4)
      .average(:duration_ms)
      .to_i
  end
end
