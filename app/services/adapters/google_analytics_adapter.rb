module Adapters
  # GA4 credentials aren't available yet (per project instructions). This
  # stub always reports "not configured" so ReportGenerator leaves
  # report_traffic's GA4 columns (total_visits, organic/direct/referral/paid
  # visits, unique_visitors, pages_per_visit) nil — which is exactly what
  # drives the "Google Analytics isn't connected yet" placeholder on the
  # report page (see ReportPresenter#ga4_available?).
  #
  # Swap this out for a real GA4 Data API client once credentials exist; the
  # #call contract (Result.success(data) / Result.failure(reason)) stays the
  # same so ReportGenerator needs no changes.
  class GoogleAnalyticsAdapter < Base
    SERVICE = "google_analytics"

    # Overrides Base#call directly (rather than #perform) since this stub is
    # never expected to have credentials configured — Base's credential check
    # would otherwise report a generic "no credentials" rather than this
    # adapter's more specific reason.
    def call
      Result.failure("google_analytics: not yet configured (no GA4 credentials)")
    end
  end
end
