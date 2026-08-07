# frozen_string_literal: true

# Shared by every domain-matching service (GhlLocationMatcher, YextEntityMatcher,
# SemrushProjectMatcher, HubspotCompanySearcher) — strips scheme/www/trailing
# slash and downcases, so two URLs for the same site compare equal regardless
# of how each external service happened to store it.
module NormalizesDomain
  private

  def normalize_domain(url)
    url.to_s.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").sub(%r{/\z}, "").downcase
  end
end
