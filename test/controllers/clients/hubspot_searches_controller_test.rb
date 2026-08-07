require "test_helper"

class Clients::HubspotSearchesControllerTest < ActionDispatch::IntegrationTest
  SEARCH_URL = "https://api.hubapi.com/crm/v3/objects/companies/search"

  setup do
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "hubspot-agency-token" }.to_json)
  end

  test "renders results for a search query" do
    sign_in_as(role: "admin")
    stub_request(:post, SEARCH_URL).to_return(status: 200, body: { results: [
      { "id" => "18628823830", "properties" => { "name" => "Adams Dental Associates", "domain" => "adamsdentalassociates.com" } }
    ] }.to_json)

    get hubspot_search_clients_path(q: "adams")

    assert_response :success
    assert_select "p", text: "Adams Dental Associates"
  end

  test "renders no results without erroring for a query with no matches" do
    sign_in_as(role: "admin")
    stub_request(:post, SEARCH_URL).to_return(status: 200, body: { results: [] }.to_json)

    get hubspot_search_clients_path(q: "nonexistent")

    assert_response :success
    assert_select "p", text: /No HubSpot companies found/
  end

  test "does not search HubSpot without a query" do
    sign_in_as(role: "admin")

    get hubspot_search_clients_path

    assert_response :success
    assert_not_requested :post, SEARCH_URL
  end

  test "support role is blocked" do
    sign_in_as(role: "support")

    get hubspot_search_clients_path

    assert_redirected_to root_path
  end
end
