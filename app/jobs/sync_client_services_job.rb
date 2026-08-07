# Runs SyncServicesChecker off the request thread — GHL/Yext/SEMrush's
# domain-match calls take several seconds combined, too slow to block a
# Puma worker on. Broadcasts each service's result *as it completes* so the
# Edit practice page shows "Checking…" until that specific service finishes,
# then updates with the result, while other services keep checking.
class SyncClientServicesJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(client_id)
    client = Client.kept.find(client_id)

    SyncServicesChecker.new(client).call_with_yields do |service, outcome, duration_ms|
      broadcast_outcome(client, service, outcome)
      log_outcome(client, service, outcome, duration_ms)
    end
  end

  private

  def broadcast_outcome(client, service, outcome)
    Turbo::StreamsChannel.broadcast_replace_to(
      client, :sync_services,
      target: "service_outcome_#{service}",
      partial: "clients/service_outcome",
      locals: { service: service, outcome: outcome }
    )
  end

  def log_outcome(client, service, outcome, duration_ms)
    ServiceSyncLog.create!(client: client, service: service,
      duration_ms: duration_ms, status: status_for(outcome))
  end

  # The three outcomes SyncServicesChecker#check returns: a Match, false
  # (checked, nothing matched), or :error (couldn't check at all).
  def status_for(outcome)
    return :success if outcome.is_a?(Data)
    return :not_found if outcome == false

    :error
  end
end
