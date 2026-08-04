require "test_helper"

class ClientsQueryTest < ActiveSupport::TestCase
  test "search filters by name, case-insensitively" do
    Client.create!(name: "Bright Smiles Dental", onboarding_status: "active")
    Client.create!(name: "Lakeside Orthodontics", onboarding_status: "active")

    result = ClientsQuery.new(search: "bright").call

    assert_equal [ "Bright Smiles Dental" ], result.clients.map(&:name)
  end

  test "status filters by onboarding status" do
    Client.create!(name: "Active Practice", onboarding_status: "active")
    Client.create!(name: "Pending Practice", onboarding_status: "pending")

    result = ClientsQuery.new(status: "pending").call

    assert_equal [ "Pending Practice" ], result.clients.map(&:name)
  end

  test "pill counts stay unfiltered by the current search or status" do
    Client.create!(name: "Active Practice", onboarding_status: "active")
    Client.create!(name: "Pending Practice", onboarding_status: "pending")

    result = ClientsQuery.new(search: "Pending", status: "pending").call

    assert_equal 1, result.active_count
    assert_equal 1, result.pending_count
    assert_equal 2, result.total_count
  end

  test "filtered_count and total_pages reflect the current filter" do
    Client.create!(name: "Active One", onboarding_status: "active")
    Client.create!(name: "Active Two", onboarding_status: "active")
    Client.create!(name: "Pending One", onboarding_status: "pending")

    result = ClientsQuery.new(status: "active").call

    assert_equal 2, result.filtered_count
    assert_equal 1, result.total_pages
  end

  test "paginates with PER_PAGE per page" do
    12.times { |i| Client.create!(name: "Practice #{i.to_s.rjust(2, '0')}", onboarding_status: "active") }

    first_page = ClientsQuery.new(page: 1).call
    second_page = ClientsQuery.new(page: 2).call

    assert_equal ClientsQuery::PER_PAGE, first_page.clients.size
    assert_equal 12 - ClientsQuery::PER_PAGE, second_page.clients.size
    assert_equal 2, first_page.total_pages
  end

  test "an unrecognized status is ignored, not raised" do
    Client.create!(name: "Some Practice", onboarding_status: "active")

    result = ClientsQuery.new(status: "not-a-real-status").call

    assert_equal 1, result.filtered_count
  end
end
