# Thin wrapper around SyncClientFromHubspot so it can run on Solid Queue.
#
# IDs in, not objects (CONVENTIONS #14). Idempotent via SyncClientFromHubspot
# itself — a retry always just re-fetches and overwrites the same fields.
class SyncHubspotClientJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(client_id)
    SyncClientFromHubspot.new(Client.find(client_id)).call
  end
end
