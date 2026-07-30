require "test_helper"

module Adapters
  class GoogleAnalyticsAdapterTest < ActiveSupport::TestCase
    test "always reports not configured, without making any HTTP request" do
      client = Client.create!(name: "Test Practice", onboarding_status: "active")

      result = GoogleAnalyticsAdapter.new(client, report_month: Date.new(2026, 6, 1)).call

      assert_not result.success?
      assert_match(/not yet configured/, result.error)
    end
  end
end
