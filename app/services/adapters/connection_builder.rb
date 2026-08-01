module Adapters
  # Shared Faraday setup for anything that makes an outbound HTTP call in this
  # app — both the third-party API adapters (Adapters::Base) and
  # SitemapScanner, which hits a client's own website rather than a
  # third-party API. Kept as one implementation so the timeout/retry policy
  # can't silently drift between the two callers again — it already had:
  # SitemapScanner's own hand-rolled copy carried the same timeouts but
  # dropped the retry middleware entirely.
  module ConnectionBuilder
    def self.build(base_url = nil, headers: {})
      Faraday.new(url: base_url, headers: headers) do |f|
        f.options.open_timeout = 10
        f.options.timeout = 15
        # Net::HTTP commits to a single resolved address per attempt and, unlike
        # curl, never falls back to a different one from a DNS round-robin pool
        # if that address is unreachable — so a real retry needs real spacing
        # (not just more attempts) to have a chance of a fresh DNS answer,
        # since resolvers commonly rotate record order between lookups but the
        # OS-level cache can hold an answer for a while. 4 tries spaced
        # 2s/4s/8s/16s apart is still fine for a background report job.
        f.request :retry, max: 4, interval: 2, backoff_factor: 2,
          exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end
  end
end
