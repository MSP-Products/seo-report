# Wraps LinkedServiceConnectionTester.test_link for one ClientServiceLink —
# enqueued immediately when a GHL/Yext/SEMrush/GA4 external_id is set or
# changed (see ClientServiceLink), the same immediate-verification pattern
# HubSpot already has via SyncHubspotClientJob, minus HubSpot's extra
# state-syncing side effects.
class TestClientServiceConnectionJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(client_service_link_id)
    LinkedServiceConnectionTester.test_link(ClientServiceLink.find(client_service_link_id))
  end
end
