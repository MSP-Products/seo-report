# Updates a Client and upserts each service's account/location ID from the "Edit practice"
# form. Unlike ClientCreator, a blank field really does clear that service's link — the edit
# form shows current state, so what you see is what gets saved.
class ClientUpdater
  def initialize(client:, attrs:, service_external_ids: {})
    @client = client
    @attrs = attrs
    @service_external_ids = service_external_ids
  end

  def call
    Client.transaction do
      client.assign_attributes(attrs)
      next client unless client.save

      sync_service_links
      client
    end
  end

  private

  attr_reader :client, :attrs, :service_external_ids

  def sync_service_links
    service_external_ids.each do |service, external_id|
      client.client_service_links.find_or_initialize_by(service: service).update!(external_id: external_id.presence)
    end
  end
end
