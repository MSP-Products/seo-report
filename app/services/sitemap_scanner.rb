# Discovers a client's website pages (SOW #4's "Website Pages Published"
# section): parses their XML sitemap first, falling back to a capped
# homepage-links crawl if no sitemap is configured or it fails to parse —
# matching Client#page_scan_method's sitemap/crawler/failed enum.
#
# Runs on its own recurring schedule (config/recurring.yml), independent of
# report generation — ReportGenerator only reads whatever this has already
# found for the report month; it never triggers a scan itself.
#
# A newly-discovered page's title/meta_description come from fetching that
# page directly (per the SOW: descriptions come from the page itself, not a
# separate source) — an already-known page just gets last_seen_at touched,
# so editing a page's title later doesn't retroactively change what a past
# report already snapshotted (see ReportPagePublished).
#
# Never raises: any failure marks the client's scan status and returns, since
# one client's broken site shouldn't affect any other client's scan.
class SitemapScanner
  MAX_CRAWLED_LINKS = 25 # homepage-only fallback, not a real recursive crawler
  USER_AGENT = "MSP-ReportBot/1.0 (+https://mysocialpractice.com)".freeze

  def initialize(client)
    @client = client
    # mark_scan's client.update! below is this scan's own write-back, not a
    # fresh save that should re-trigger anything — without this, it would
    # redundantly re-enqueue a full HubSpot sync and connection checks for
    # every other linked service on every nightly scan, for every client,
    # via Client#sync_linked_services (see SyncClientFromHubspot, which hit
    # this same class of bug for real before being caught and fixed).
    @client.skip_service_sync = true
  end

  def call
    urls, method = discover_urls

    if urls.blank?
      mark_scan(method: "failed", status: "failed")
      return
    end

    urls.each { |url| record_page(url) }
    mark_scan(method: method, status: "success")
  rescue StandardError => e
    Rails.logger.warn("SitemapScanner: #{client.name} — #{e.message}")
    mark_scan(method: "failed", status: "failed")
  end

  private

  attr_reader :client

  def discover_urls
    sitemap_urls = fetch_sitemap_urls
    return [ sitemap_urls, "sitemap" ] if sitemap_urls.present?

    [ fetch_crawled_urls, "crawler" ]
  end

  def fetch_sitemap_urls
    response = connection.get(sitemap_url)
    doc = Nokogiri::XML(response.body)
    doc.remove_namespaces!
    doc.css("url > loc").map { |node| node.text.strip }.presence
  rescue Faraday::Error, Nokogiri::XML::SyntaxError
    nil
  end

  def fetch_crawled_urls
    response = connection.get(homepage_url)
    doc = Nokogiri::HTML(response.body)
    host = URI.parse(homepage_url).host

    doc.css("a[href]").filter_map { |a| same_domain_link(a["href"], host) }.uniq.first(MAX_CRAWLED_LINKS).presence
  rescue Faraday::Error, URI::InvalidURIError
    nil
  end

  def same_domain_link(href, host)
    absolute = URI.join(homepage_url, href.to_s)
    return nil unless absolute.host == host

    # A fragment ("#content", "#") points at a spot on the same document, not
    # a different page — strip it so e.g. an in-page "skip to content" link
    # doesn't get counted as a separate page from the homepage itself.
    absolute.fragment = nil
    absolute.to_s
  rescue URI::InvalidURIError
    nil
  end

  def record_page(url)
    page = client.sitemap_pages.find_or_initialize_by(url: url)

    if page.new_record?
      meta = fetch_page_meta(url)
      page.title = meta[:title]
      page.meta_description = meta[:description]
      page.first_seen_at = Time.current
    end

    page.last_seen_at = Time.current
    page.save!
  end

  def fetch_page_meta(url)
    response = connection.get(url)
    doc = Nokogiri::HTML(response.body)

    { title: doc.at_css("title")&.text&.strip, description: doc.at_css("meta[name='description']")&.[]("content")&.strip }
  rescue Faraday::Error
    { title: nil, description: nil }
  end

  def mark_scan(method:, status:)
    client.update!(page_scan_method: method, last_page_scan_status: status, last_page_scan_at: Time.current)
  end

  def sitemap_url
    client.sitemap_url.presence || "#{homepage_url.chomp('/')}/sitemap.xml"
  end

  def homepage_url
    url = client.website_url.to_s
    url.start_with?("http") ? url : "https://#{url}"
  end

  def connection
    Adapters::ConnectionBuilder.build(headers: { "User-Agent" => USER_AGENT })
  end
end
