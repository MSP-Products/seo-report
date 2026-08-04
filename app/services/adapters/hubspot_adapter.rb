module Adapters
  # HubSpot is the source of truth for onboarding status, onboarding date, and
  # AI SEO enrollment (SOW #9), and a fallback source for practice header
  # fields alongside Yext.
  #
  # Credentials shape: {"access_token" => "..."} (HubSpot private-app token).
  # external_id: the HubSpot Company record ID for this client.
  #
  # Verified against a real MSP HubSpot portal — none of these have a
  # dedicated property named the obvious way. `active` (a plain boolean) is
  # the closest to onboarding status MSP actually uses; `gmb_seo_start_date`
  # is the onboarding date (confirmed with MSP — this app's core SEO product
  # predates the "GMB" name but that's still the field in use); and
  # `service_purchased` is a semicolon-delimited multi-select of every
  # service tag a client has, including "AI SEO".
  class HubspotAdapter < Base
    SERVICE = "hubspot"
    BASE_URL = "https://api.hubapi.com"
    PROPERTIES = %w[name address website active gmb_seo_start_date service_purchased].freeze
    AI_SEO_TAG = "AI SEO"

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
        onboarding_status: onboarding_status_from(properties["active"]),
        onboarded_at: properties["gmb_seo_start_date"].presence && Date.parse(properties["gmb_seo_start_date"]),
        ai_seo_enrolled: service_tags(properties["service_purchased"]).include?(AI_SEO_TAG)
      )
    end

    # `active` has no "pending" equivalent — a client only reaches this sync
    # once they already have a real HubSpot company record, so "not active"
    # here means offboarded, not merely not-yet-onboarded.
    def onboarding_status_from(active)
      ActiveModel::Type::Boolean.new.cast(active) ? "active" : "offboarded"
    end

    def service_tags(service_purchased)
      service_purchased.to_s.split(";")
    end
  end
end
