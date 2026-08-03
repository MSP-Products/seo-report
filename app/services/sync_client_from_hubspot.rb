# Pulls a client's practice details and onboarding/AI-SEO status from HubSpot
# and writes them onto the Client record. Shared by ReportGenerator (as part
# of generating a report) and the standalone pre-generation sync job — the
# latter exists so EnqueueMonthlyReportsJob's Client.kept.active targeting
# reflects HubSpot's current state, not whatever a prior report run last
# wrote (a client that just went active in HubSpot wouldn't otherwise be
# picked up until the report after next).
class SyncClientFromHubspot
  def initialize(client)
    @client = client
  end

  def call
    result = Adapters::HubspotAdapter.new(client).call
    return result unless result.success?

    client.update!(result.data.slice(:name, :address, :website_url, :onboarding_status, :onboarded_at, :ai_seo_enrolled).compact)
    result
  end

  private

  attr_reader :client
end
