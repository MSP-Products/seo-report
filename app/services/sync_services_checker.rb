# frozen_string_literal: true

# Orchestrates GhlLocationMatcher/YextEntityMatcher/SemrushProjectMatcher for
# one Client, checking only services whose external_id is currently blank —
# never overwrites an existing link. One service's failure doesn't block the
# others: each is isolated, so a GHL outage still lets Yext/SEMrush results
# through.
class SyncServicesChecker
  MATCHERS = { "ghl" => GhlLocationMatcher, "yext" => YextEntityMatcher, "semrush" => SemrushProjectMatcher }.freeze

  # The one source of truth for which services a sync would even attempt —
  # shared with Clients::SyncServicesController, which needs this list up
  # front (before the slow #call below runs) to mark each one "Checking…".
  def self.unlinked_services(client)
    MATCHERS.keys.select { |service| link_blank?(client, service) }
  end

  def self.link_blank?(client, service)
    client.client_service_links.find { |link| link.service == service }&.external_id.blank?
  end
  private_class_method :link_blank?

  def initialize(client)
    @client = client
  end

  # Yields each service's result as it completes, so broadcasts can go out
  # one at a time instead of all at once. Used by SyncClientServicesJob to
  # keep "Checking…" visible until each specific service finishes.
  def call_with_yields
    self.class.unlinked_services(@client).each do |service|
      outcome = check(service)
      yield(service, outcome)
    end
  end

  # Returns a Hash of service key => Match (found) | false (checked, no
  # match) | :error (couldn't check) — only for services with a blank
  # external_id; a linked service is omitted entirely. Used by tests.
  def call
    self.class.unlinked_services(@client).index_with { |service| check(service) }
  end

  private

  def check(service)
    MATCHERS.fetch(service).new(@client).call || false
  rescue Faraday::Error, GhlOauthClient::NotConnectedError
    :error
  end
end
