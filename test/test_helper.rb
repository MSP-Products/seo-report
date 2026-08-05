ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!

# The services table is reference data seeded by its own migration (see
# CreateServices) — but the test database is prepared via schema load, not a
# full migration replay, so that seed never lands here. Bootstrap it directly
# instead; this is schema-adjacent lookup data, not a business record, so it
# doesn't conflict with this project's no-fixtures convention.
Service::KEYS.each { |key| Service.find_or_create_by!(key: key) }

Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers, once the suite is large
    # enough to be worth it — multi-process parallelization's own IPC hung
    # outright the moment this suite first crossed Rails' default 50-test
    # threshold (workers all finished, exited, and were never reaped by the
    # parent — a coordination bug in this environment, not in the tests
    # themselves), so the threshold is raised well above the current size
    # rather than fought. Lower it again once the suite has grown enough that
    # parallelization's speed actually matters more than its fragility here.
    parallelize(workers: :number_of_processors, threshold: 200)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationHelpers
end
