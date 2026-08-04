require "test_helper"

class ClientCreatorTest < ActiveSupport::TestCase
  test "creates a client with no service links" do
    client = ClientCreator.new(attrs: { name: "Bright Smiles Dental" }).call

    assert client.persisted?
    assert_equal "pending", client.onboarding_status
    assert_empty client.client_service_links
  end

  test "creates a service link only for services with a non-blank external id" do
    client = ClientCreator.new(
      attrs: { name: "Bright Smiles Dental" },
      service_external_ids: { "hubspot" => "company-1", "yext" => "", "semrush" => "  " }
    ).call

    assert_equal [ "hubspot" ], client.client_service_links.pluck(:service)
    assert_equal "company-1", client.client_service_links.first.external_id
  end

  test "returns an unpersisted client with errors and creates no links on invalid input" do
    client = ClientCreator.new(attrs: { name: "" }, service_external_ids: { "hubspot" => "company-1" }).call

    assert_not client.persisted?
    assert client.errors[:name].any?
    assert_equal 0, ClientServiceLink.count
  end
end
