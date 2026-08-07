# frozen_string_literal: true

# Suggests a GHL location for a Client by matching each sub-account's website
# against the client's own website_url — a suggestion for an admin to confirm
# on the Edit practice page, never a silent auto-assign (see
# Clients::GhlLocationMatchesController). Agency-scoped, not per-client, so
# this isn't an Adapters::Base subclass — closer in shape to GhlOauthClient
# itself than to GhlAdapter.
class GhlLocationMatcher
  include NormalizesDomain

  Match = Data.define(:location_id, :name, :website)

  BASE_URL = "https://services.leadconnectorhq.com"
  API_VERSION = "2021-07-28"
  PAGE_SIZE = 100 # confirmed live — GHL's docs only document a default of 10

  def initialize(client)
    @client = client
  end

  def call
    target = normalize_domain(@client.website_url)
    return nil if target.blank?

    each_location.find { |location| normalize_domain(location["website"]) == target }
      &.then { |location| Match.new(location_id: location["id"], name: location["name"], website: location["website"]) }
  end

  private

  def each_location
    return to_enum(:each_location) unless block_given?

    company_id = AgencyConnection.find_by(service: "ghl")&.credentials&.dig("company_id")
    return if company_id.blank?

    skip = 0
    loop do
      page = fetch_page(company_id, skip)
      page.each { |location| yield location }
      break if page.size < PAGE_SIZE

      skip += PAGE_SIZE
    end
  end

  def fetch_page(company_id, skip)
    response = connection.get("/locations/search", { companyId: company_id, skip: skip, limit: PAGE_SIZE })
    JSON.parse(response.body).fetch("locations", [])
  end

  def connection
    token = GhlOauthClient.new.agency_access_token!
    Adapters::ConnectionBuilder.build(BASE_URL, headers: { "Authorization" => "Bearer #{token}", "Version" => API_VERSION })
  end
end
