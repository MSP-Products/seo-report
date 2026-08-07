require "test_helper"

class SitemapScannerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @client = Client.create!(name: "Test Practice", website_url: "example.com", onboarding_status: "active")
  end

  test "discovers pages from a sitemap and fetches title/description for new ones" do
    stub_request(:get, "https://example.com/sitemap.xml").to_return(status: 200, body: <<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://example.com/</loc></url>
        <url><loc>https://example.com/dental-implants/</loc></url>
      </urlset>
    XML
    stub_request(:get, "https://example.com/").to_return(status: 200, body: "<html><head><title>Home</title></head></html>")
    stub_request(:get, "https://example.com/dental-implants/").to_return(status: 200, body: <<~HTML)
      <html><head><title>Dental Implants</title><meta name="description" content="Everything about implants."></head></html>
    HTML

    SitemapScanner.new(@client).call

    @client.reload
    assert_equal "sitemap", @client.page_scan_method
    assert_equal "success", @client.last_page_scan_status
    assert @client.last_page_scan_at.present?

    page = @client.sitemap_pages.find_by(url: "https://example.com/dental-implants/")
    assert_equal "Dental Implants", page.title
    assert_equal "Everything about implants.", page.meta_description
    assert page.first_seen_at.present?
    assert page.last_seen_at.present?
  end

  test "falls back to crawling the homepage when the sitemap is unavailable" do
    stub_request(:get, "https://example.com/sitemap.xml").to_return(status: 404)
    stub_request(:get, "https://example.com/").to_return(status: 200, body: <<~HTML)
      <html><body>
        <a href="/services/">Services</a>
        <a href="https://other-site.com/ad">Off-domain, should be ignored</a>
        <a href="#content">Skip to content — same page as the homepage, not a new one</a>
        <a href="#">Back to top — same page too</a>
      </body></html>
    HTML
    stub_request(:get, "https://example.com/services/").to_return(status: 200, body: "<html><head><title>Services</title></head></html>")

    SitemapScanner.new(@client).call

    @client.reload
    assert_equal "crawler", @client.page_scan_method
    assert_equal "success", @client.last_page_scan_status
    # The homepage itself is a legitimate page and does show up (discovered
    # via its own fragment links) — but only once, not twice, thanks to
    # fragment-stripping; "/services/" is the other, genuinely distinct page.
    assert_equal [ "https://example.com", "https://example.com/services/" ], @client.sitemap_pages.pluck(:url).sort
  end

  test "marks the client's scan as failed when neither sitemap nor crawl succeeds" do
    stub_request(:get, "https://example.com/sitemap.xml").to_return(status: 500)
    stub_request(:get, "https://example.com/").to_return(status: 500)

    SitemapScanner.new(@client).call

    @client.reload
    assert_equal "failed", @client.page_scan_method
    assert_equal "failed", @client.last_page_scan_status
    assert_equal 0, @client.sitemap_pages.count
  end

  test "touches last_seen_at without re-fetching an already-known page" do
    existing = @client.sitemap_pages.create!(
      url: "https://example.com/", title: "Original Title", meta_description: "Original description",
      first_seen_at: 2.months.ago, last_seen_at: 2.months.ago
    )
    stub_request(:get, "https://example.com/sitemap.xml").to_return(status: 200, body: <<~XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://example.com/</loc></url>
      </urlset>
    XML

    SitemapScanner.new(@client).call

    existing.reload
    assert_equal "Original Title", existing.title
    assert_in_delta Time.current, existing.last_seen_at, 5.seconds
    assert_not_requested :get, "https://example.com/" # never re-fetched for an already-known page
  end

  # Regression: mark_scan's client.update! used to re-trigger
  # Client#sync_linked_services on every nightly scan, redundantly firing a
  # full HubSpot sync and connection checks for every other linked service —
  # unrelated to what a sitemap scan is even for. Same class of bug caught
  # for real in SyncClientFromHubspot; fixed here the same way.
  test "does not re-enqueue any service sync as a side effect of its own scan" do
    @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    stub_request(:get, "https://example.com/sitemap.xml").to_return(status: 500)
    stub_request(:get, "https://example.com/").to_return(status: 500)

    assert_no_enqueued_jobs { SitemapScanner.new(@client).call }
  end
end
