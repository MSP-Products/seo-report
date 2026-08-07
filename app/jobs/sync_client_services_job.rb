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

    SyncServicesChecker.new(client).call_with_yields do |service, outcome|
      # Record the timing and result for this service check
      start_time = Time.current

      Turbo::StreamsChannel.broadcast_replace_to(
        client, :sync_services,
        target: "service_outcome_#{service}",
        partial: "clients/service_outcome",
        locals: { service: service, outcome: outcome }
      )

      duration_ms = ((Time.current - start_time) * 1000).to_i

      # Determine status and error message
      status = if outcome.is_a?(Data)
                 :success
               elsif outcome == false
                 :not_found
               else
                 :error
               end

      ServiceSyncLog.create!(
        client: client,
        service: service,
        duration_ms: duration_ms,
        status: status,
        error_message: nil
      )
    end
  end
end
