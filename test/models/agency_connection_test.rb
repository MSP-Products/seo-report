require "test_helper"

class AgencyConnectionTest < ActiveSupport::TestCase
  test "oauth_managed? is true only for ghl" do
    assert AgencyConnection.new(service: "ghl").oauth_managed?
    assert_not AgencyConnection.new(service: "hubspot").oauth_managed?
  end

  test "status_label for ghl reflects credential_status instead of 'Not available yet'" do
    connection = AgencyConnection.new(service: "ghl", credential_status: "active")

    assert_equal "Active", connection.status_label
  end

  test "status_label branches: expiring_soon, expired, invalid, unverified, not configured" do
    assert_equal "Expiring soon", AgencyConnection.new(service: "hubspot", credential_status: "expiring_soon").status_label
    assert_equal "Expired", AgencyConnection.new(service: "hubspot", credential_status: "expired").status_label
    assert_equal "Needs attention", AgencyConnection.new(service: "hubspot", credential_status: "invalid").status_label
    assert_equal "Unverified", AgencyConnection.new(service: "hubspot", encrypted_credentials: { access_token: "x" }.to_json).status_label
    assert_equal "Not configured", AgencyConnection.new(service: "hubspot").status_label
  end

  test "status_dot_class branches" do
    assert_equal "bg-emerald-500", AgencyConnection.new(service: "hubspot", credential_status: "active").status_dot_class
    assert_equal "bg-amber-500", AgencyConnection.new(service: "hubspot", credential_status: "expiring_soon").status_dot_class
    assert_equal "bg-red-500", AgencyConnection.new(service: "hubspot", credential_status: "expired").status_dot_class
    assert_equal "bg-red-500", AgencyConnection.new(service: "hubspot", credential_status: "invalid").status_dot_class
    assert_equal "bg-slate-300", AgencyConnection.new(service: "hubspot").status_dot_class
  end
end
