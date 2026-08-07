require "test_helper"

class ClientsHelperTest < ActionView::TestCase
  # Each matcher names its id and domain fields in its own service's terminology,
  # so these two helpers are the only thing keeping _service_outcome.html.erb from
  # branching per service. A wrong mapping renders a blank suggestion caption and a
  # "Use this match" button that pastes nothing.
  test "service_match_id reads each service's own id field" do
    assert_equal "loc-1", service_match_id("ghl", ghl_match)
    assert_equal "co-adams-dental", service_match_id("yext", yext_match)
    assert_equal "30632499_5220001", service_match_id("semrush", semrush_match)
  end

  test "service_match_detail reads each service's own domain field" do
    assert_equal "https://www.adamsdentalassociates.com", service_match_detail("ghl", ghl_match)
    assert_equal "https://www.adamsdentalassociates.com", service_match_detail("yext", yext_match)
    assert_equal "adamsdentalassociates.com", service_match_detail("semrush", semrush_match)
  end

  # fetch, not [], so a service added to SyncServicesChecker::MATCHERS without a
  # mapping here fails loudly instead of rendering an empty caption.
  test "service_match_id raises for a service with no mapping" do
    assert_raises(KeyError) { service_match_id("hubspot", ghl_match) }
  end

  private

  def ghl_match
    GhlLocationMatcher::Match.new(location_id: "loc-1", name: "Adams Dental Associates",
      website: "https://www.adamsdentalassociates.com")
  end

  def yext_match
    YextEntityMatcher::Match.new(entity_id: "co-adams-dental", name: "Adams Dental Associates",
      website: "https://www.adamsdentalassociates.com")
  end

  def semrush_match
    SemrushProjectMatcher::Match.new(project_campaign_id: "30632499_5220001",
      name: "Adams Dental", domain: "adamsdentalassociates.com")
  end
end
