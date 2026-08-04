require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "city_state extracts city and state, stripping the zip" do
    client = Client.create!(name: "Woodside Dental", onboarding_status: "active",
      address: "123 Oak Street, San Francisco, CA 94102")

    assert_equal "San Francisco, CA", client.city_state
  end

  test "city_state falls back to the raw address when it can't be parsed" do
    client = Client.create!(name: "No Address Practice", onboarding_status: "active", address: "PO Box 12")

    assert_equal "PO Box 12", client.city_state
  end

  test "city_state handles a blank address" do
    client = Client.create!(name: "Blank Address Practice", onboarding_status: "active")

    assert_nil client.city_state
  end
end
