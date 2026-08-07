require "test_helper"

class Clients::SyncServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}",
      onboarding_status: "active", website_url: "https://www.adamsdentalassociates.com/")
  end

  test "enqueues a background check and responds with a Searching placeholder per unlinked service" do
    sign_in_as(role: "admin")

    assert_enqueued_with(job: SyncClientServicesJob, args: [ @client.id ]) do
      post client_sync_services_path(@client)
    end

    assert_response :success
    assert_match "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=service_outcome_ghl]"
    assert_select "turbo-stream[action=replace][target=service_outcome_yext]"
    assert_select "turbo-stream[action=replace][target=service_outcome_semrush]"
    assert_select "turbo-stream template", text: /Searching…/, count: 3
  end

  test "does not mark an already-linked service as Checking" do
    @client.client_service_links.create!(service: "ghl", external_id: "already-linked")
    sign_in_as(role: "admin")

    post client_sync_services_path(@client)

    assert_response :success
    assert_select "turbo-stream[target=service_outcome_ghl]", count: 0
    assert_select "turbo-stream[target=service_outcome_yext]"
    assert_select "turbo-stream[target=service_outcome_semrush]"
  end

  test "an Account Manager is blocked" do
    sign_in_as(role: "account_manager")

    assert_no_enqueued_jobs only: SyncClientServicesJob do
      post client_sync_services_path(@client)
    end

    assert_redirected_to root_path
  end
end
