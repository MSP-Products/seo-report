# One job tests every already-linked GHL/Yext/SEMrush/GA4 connection across
# every kept client in a single run, rather than fanning out a job per
# client — each check is one lightweight API call, not a full report-data
# pull, so a single hourly run comfortably covers the whole client list.
class TestClientServiceConnectionsJob < ApplicationJob
  queue_as :default

  def perform
    LinkedServiceConnectionTester.new.call
  end
end
