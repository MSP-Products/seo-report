# frozen_string_literal: true

# Records how long each service takes to check during sync, success/failure status,
# and any errors — for accurate time estimates and debugging.
class ServiceSyncLog < ApplicationRecord
  belongs_to :client

  enum :status, { success: "success", not_found: "not_found", error: "error" }, suffix: true

  RECENT_CHECKS = 4

  # Average duration of the last few successful checks of one service — a short
  # window so the countdown tracks a service that has recently got slower,
  # rather than being anchored by its whole history. Returns 0 when there is no
  # history, which is the caller's cue to use its own default estimate.
  #
  # The window has to be applied in a subquery: `.limit(n).average` silently
  # ignores the limit, because SQL applies LIMIT to the aggregate's single
  # output row rather than to the rows being averaged.
  def self.average_duration_for(service)
    recent = where(service: service, status: :success).order(created_at: :desc).limit(RECENT_CHECKS)

    from(recent, :service_sync_logs).average(:duration_ms).to_i
  end
end
