require "test_helper"

class ClientUpdaterTest < ActiveSupport::TestCase
  test "updates the client's attributes" do
    client = Client.create!(name: "Old Name", onboarding_status: "active")

    updated = ClientUpdater.new(client: client, attrs: { name: "New Name", phone: "555-0100" }).call

    assert updated.persisted?
    assert_equal "New Name", updated.reload.name
    assert_equal "555-0100", updated.phone
  end

  test "upserts a service link with a non-blank external_id" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    ClientUpdater.new(client: client, attrs: {}, service_external_ids: { "hubspot" => "company-1" }).call

    assert_equal "company-1", client.client_service_links.find_by(service: "hubspot").external_id
  end

  test "clears an existing link when its field is submitted blank" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")
    client.client_service_links.create!(service: "hubspot", external_id: "company-1")

    ClientUpdater.new(client: client, attrs: {}, service_external_ids: { "hubspot" => "" }).call

    assert_nil client.client_service_links.find_by(service: "hubspot").external_id
  end

  test "returns an unpersisted client with errors and touches no links on invalid input" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")
    client.client_service_links.create!(service: "hubspot", external_id: "company-1")

    result = ClientUpdater.new(client: client, attrs: { name: "" }, service_external_ids: { "hubspot" => "changed" }).call

    assert result.errors[:name].any?
    assert_equal "company-1", client.client_service_links.find_by(service: "hubspot").external_id
  end
end
