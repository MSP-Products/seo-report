# frozen_string_literal: true

# Loads the client for member actions and owns the strong params for
# create/update — kept out of ClientsController per CLAUDE.md's
# controllers-are-actions-only rule.
module FindsClient
  extend ActiveSupport::Concern

  included do
    before_action :set_client, only: [ :show, :edit, :update, :destroy ]
  end

  private

  def set_client
    @client = Client.kept.find(params[:id])
  end

  # onboarding_status/onboarded_at/ai_seo_enrolled are excluded: SyncClientFromHubspot
  # overwrites them from HubSpot on every report run, so this form only shows them
  # read-only (see clients/_form.html.erb) rather than let an admin edit a value
  # the next sync would silently clobber. sitemap_url is excluded too — it's
  # discovered from robots.txt during report generation, never entered by hand.
  def client_params
    params.require(:client).permit(:name, :address, :website_url, :phone,
      client_service_links_attributes: [ :id, :service, :external_id ])
  end
end
