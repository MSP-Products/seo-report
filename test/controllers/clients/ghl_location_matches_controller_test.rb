require "test_helper"

class Clients::GhlLocationMatchesControllerTest < ActionDispatch::IntegrationTest
  LOCATIONS_URL = "https://services.leadconnectorhq.com/locations/search"

  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}",
      onboarding_status: "active", website_url: "https://www.adamsdentalassociates.com/")
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "agency-access-token", refresh_token: "agency-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 2.hours.from_now)
  end

  test "renders Edit practice with a suggested match when one is found" do
    sign_in_as(role: "admin")
    stub_request(:get, LOCATIONS_URL)
      .with(query: hash_including("skip" => "0"))
      .to_return(status: 200, body: { locations: [
        { "id" => "loc-2", "name" => "Adams Dental Associates", "website" => "https://www.adamsdentalassociates.com" }
      ] }.to_json)

    post client_ghl_location_match_path(@client)

    assert_response :success
    assert_select "code", text: "loc-2"
  end

  test "renders Edit practice with a not-found message when no location matches" do
    sign_in_as(role: "admin")
    stub_request(:get, LOCATIONS_URL)
      .with(query: hash_including("skip" => "0"))
      .to_return(status: 200, body: { locations: [] }.to_json)

    post client_ghl_location_match_path(@client)

    assert_response :success
    assert_select "p", text: /No GHL location found/
  end

  test "shows a generic alert and does not crash when GHL errors" do
    sign_in_as(role: "admin")
    stub_request(:get, LOCATIONS_URL).with(query: hash_including({})).to_return(status: 500)

    post client_ghl_location_match_path(@client)

    assert_response :success
    assert_match(/Couldn.t reach GoHighLevel/, flash[:alert])
  end

  test "support role is blocked" do
    sign_in_as(role: "support")

    post client_ghl_location_match_path(@client)

    assert_redirected_to root_path
    assert_not_requested :get, LOCATIONS_URL
  end
end
