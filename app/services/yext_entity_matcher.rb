# frozen_string_literal: true

# Suggests a Yext entity for a Client by matching each of the agency's
# entities' own website against the client's website_url — same "suggestion,
# not a silent auto-assign" contract as GhlLocationMatcher (see
# Clients::SyncServicesController).
class YextEntityMatcher
  include NormalizesDomain

  Match = Data.define(:entity_id, :name, :website)

  BASE_URL = "https://api.yextapis.com"
  API_VERSION = "20240101"
  PAGE_SIZE = 50 # Yext's documented max for this endpoint (GHL's is 100)

  def initialize(client)
    @client = client
  end

  # The entity's ID lives at meta.id (a slug like "co-green-mountain"), not a
  # top-level id field — confirmed live, and matches the external_id shape
  # Adapters::YextAdapter's existing single-entity GET call already expects.
  def call
    target = normalize_domain(@client.website_url)
    return nil if target.blank?

    each_entity.find { |entity| normalize_domain(entity.dig("websiteUrl", "url")) == target }
      &.then { |entity| Match.new(entity_id: entity.dig("meta", "id"), name: entity["name"], website: entity.dig("websiteUrl", "url")) }
  end

  private

  def each_entity
    return to_enum(:each_entity) unless block_given?

    api_key = AgencyConnection.find_by(service: "yext")&.credentials&.dig("api_key")
    return if api_key.blank?

    offset = 0
    loop do
      entities = fetch_page(api_key, offset)
      entities.each { |entity| yield entity }
      break if entities.size < PAGE_SIZE

      offset += PAGE_SIZE
    end
  end

  # Same "response" wrapper every other Yext call in this app already
  # unwraps (see Adapters::YextAdapter#response_data).
  def fetch_page(api_key, offset)
    response = connection.get("/v2/accounts/me/entities", { api_key: api_key, v: API_VERSION, limit: PAGE_SIZE, offset: offset })
    JSON.parse(response.body).dig("response", "entities") || []
  end

  def connection
    Adapters::ConnectionBuilder.build(BASE_URL, headers: { "Content-Type" => "application/json" })
  end
end
