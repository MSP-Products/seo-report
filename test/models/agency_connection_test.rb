require "test_helper"

class AgencyConnectionTest < ActiveSupport::TestCase
  test "all_services returns all five services, including ones never configured" do
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "token" }.to_json)

    connections = AgencyConnection.all_services

    assert_equal 5, connections.size
    assert_equal %w[semrush yext google_analytics ghl hubspot].sort, connections.map(&:service).sort
    unconfigured = connections.find { |c| c.service == "yext" }
    assert_not unconfigured.persisted?
  end
end
