ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!

# The services table is reference data seeded by its own migration (see
# CreateServices) — but the test database is prepared via schema load, not a
# full migration replay, so that seed never lands here. Bootstrap it once per
# worker process instead; this is schema-adjacent lookup data, not a business
# record, so it doesn't conflict with this project's no-fixtures convention.
Service::KEYS.each { |key| Service.find_or_create_by!(key: key) }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
