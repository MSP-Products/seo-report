module Adapters
  # HubSpot is the source of truth for onboarding status and AI SEO enrollment
  # (SOW #9), and a fallback source for practice header fields alongside Yext.
  #
  # Credentials shape: {"access_token" => "..."} (HubSpot private-app token).
  # external_id: the HubSpot Company record ID for this client.
  #
  # NOTE: onboarding_status/ai_seo_enrolled are read from custom Company
  # properties. The exact property names below are a placeholder convention —
  # confirm against MSP's actual HubSpot property setup before going live.
  class HubspotAdapter < Base
    SERVICE = "hubspot"
    BASE_URL = "https://api.hubapi.com"
    PROPERTIES = %w[name address website onboarding_status onboarded_at ai_seo_enrolled].freeze

    private

    def perform
      return Result.failure("hubspot: no company id configured for this client") if external_id.blank?

      response = connection(BASE_URL, headers: { "Authorization" => "Bearer #{credentials["access_token"]}" })
        .get("/crm/v3/objects/companies/#{external_id}", { properties: PROPERTIES.join(",") })

      properties = JSON.parse(response.body).fetch("properties", {})

      Result.success(
        name: properties["name"],
        address: properties["address"],
        website_url: properties["website"],
        onboarding_status: properties["onboarding_status"],
        onboarded_at: properties["onboarded_at"].presence && Date.parse(properties["onboarded_at"]),
        ai_seo_enrolled: ActiveModel::Type::Boolean.new.cast(properties["ai_seo_enrolled"])
      )
    end
  end
end
