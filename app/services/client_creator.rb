# Creates a Client and, for any service the caller supplied an account/location ID for,
# a matching ClientServiceLink — the "Add practice" form's one write spanning two models.
class ClientCreator
  def initialize(attrs:, service_external_ids: {})
    @attrs = attrs
    @service_external_ids = service_external_ids
  end

  def call
    Client.transaction do
      client = Client.new(attrs)
      client.onboarding_status ||= "pending"
      next client unless client.save

      link_services(client)
      client
    end
  end

  private

  attr_reader :attrs, :service_external_ids

  def link_services(client)
    service_external_ids.each do |service, external_id|
      next if external_id.blank?

      client.client_service_links.create!(service: service, external_id: external_id)
    end
  end
end
