# frozen_string_literal: true

# Searches HubSpot's Companies by free-text name or domain, for the Add
# client page's "Import from HubSpot" flow — picking a result sets that
# company's ID as the new client's HubSpot external_id, reusing the existing,
# unchanged SyncClientFromHubspot pipeline from there.
#
# Not scoped to any Client (there isn't one yet at search time) — uses the
# agency-wide HubSpot connection only, same Bearer access token
# HubspotAdapter already uses for its per-ID lookups.
class HubspotCompanySearcher
  Match = Data.define(:company_id, :name, :domain)

  BASE_URL = "https://api.hubapi.com"
  SEARCH_PATH = "/crm/v3/objects/companies/search"

  def initialize(query)
    @query = query
  end

  def call
    return [] if @query.blank?

    access_token = AgencyConnection.find_by(service: "hubspot")&.credentials&.dig("access_token")
    return [] if access_token.blank?

    response = connection(access_token).post(SEARCH_PATH) do |req|
      req.body = {
        filterGroups: [
          { filters: [ { propertyName: "domain", operator: "CONTAINS_TOKEN", value: @query } ] },
          { filters: [ { propertyName: "name", operator: "CONTAINS_TOKEN", value: @query } ] }
        ],
        properties: %w[name domain],
        limit: 20
      }.to_json
    end

    JSON.parse(response.body).fetch("results", []).map do |result|
      Match.new(company_id: result["id"], name: result.dig("properties", "name"), domain: result.dig("properties", "domain"))
    end
  end

  private

  def connection(access_token)
    Adapters::ConnectionBuilder.build(BASE_URL,
      headers: { "Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json" })
  end
end
