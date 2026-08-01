# Thin wrapper around SitemapScanner so it can run on Solid Queue's recurring
# schedule (config/recurring.yml). No retry_on here — SitemapScanner itself
# never raises (a broken client site marks that client's scan as failed and
# returns), and the next day's scheduled run is the natural retry.
class ScanClientSitemapJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(client_id)
    SitemapScanner.new(Client.find(client_id)).call
  end
end
