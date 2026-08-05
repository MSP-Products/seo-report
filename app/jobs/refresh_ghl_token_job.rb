# Keeps the agency-wide GHL OAuth grant from ever sitting near expiry between
# monthly report runs (see config/recurring.yml's hourly schedule). GhlAdapter
# already refreshes lazily on demand via GhlOauthClient#location_access_token!,
# but that only fires once a month at report-generation time — this job is the
# proactive backstop so a stale token is never the thing report generation
# discovers the hard way.
class RefreshGhlTokenJob < ApplicationJob
  queue_as :default

  retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3

  def perform
    GhlOauthClient.new.refresh_if_stale!
  end
end
