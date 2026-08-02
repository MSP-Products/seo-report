---
title: Page scan
slug: page-scan
status: shipped
last_verified: 2026-08-02
related: [report-generation, monthly-report]
---

# Page scan

> **Status:** shipped · **Last verified:** 2026-08-02
>
> The daily scan of each practice's website that discovers new pages, feeding the report's
> "Pages published" section.

---

## For everyone

### Purpose

Part of what MSP does for a practice is publish new pages on their site — service pages,
location pages, and so on. The report shows which pages appeared during the month, so the
practice can see that work.

Rather than asking anyone to record pages by hand, the system watches each practice's
website and notices when a page appears that it has not seen before.

### Who uses it

Nobody directly. It runs on its own each night. MSP staff see the result in the report's
"Pages published" section.

### How it behaves

1. Every night, each active practice's website is checked.
2. The system looks for the site's sitemap — the standard index of pages most sites
   publish — and reads the list of page addresses from it.
3. If there is no usable sitemap, it falls back to reading links from the practice's
   homepage instead, up to a limit.
4. Any address it has never seen before is recorded as new, and its title and description
   are read from the page itself at that moment.
5. Addresses already known are simply marked as still present.

A page counts as "published" in whichever month it was **first** seen. When a report is
generated, it includes the pages first seen during that month.

**Titles are captured once, when the page is first discovered.** Editing a page's title
later does not change what an earlier report already showed.

### When data is missing

| Situation | Effect |
|---|---|
| The practice's site has no sitemap | Falls back to scanning homepage links, capped at 25 pages |
| Neither the sitemap nor the homepage can be read | The scan is marked failed for that practice; their next report shows no new pages |
| A page loads but has no title or description | The page is still recorded, with those fields empty |
| The scan has never run for a practice | Their report shows no pages, regardless of what they actually published |
| No new pages that month | The report section shows an empty state |

One practice's broken website never affects another practice's scan.

### FAQ

**Q: We published a page but it's not in the report.**
A: Three possibilities. It may not be in the sitemap. The month's report may have been
generated before the page was discovered — regenerating picks it up. Or the practice's
scan may be failing; that is visible on the practice record.

**Q: Why does an old page show as new?**
A: A page counts as new the first time the system *sees* it, not when it was actually
created. A page that existed before we started scanning is recorded on the first scan
after that.

**Q: We renamed a page. Does the report update?**
A: No, and deliberately. The title is captured when first discovered, so past reports stay
a true record. A changed address, though, counts as a different page.

**Q: Does this slow the practice's website down?**
A: No. It fetches a handful of pages once a night, identifying itself as our bot.

---

## For developers

### How it works

`SitemapScanner` takes a `Client` and runs `#call`:

1. **`discover_urls`** — try `fetch_sitemap_urls` first; fall back to `fetch_crawled_urls`.
2. **`fetch_sitemap_urls`** — GET the client's `sitemap_url`, or `<homepage>/sitemap.xml`
   by default. Parses with Nokogiri, `remove_namespaces!`, selects `url > loc`. Returns
   `nil` on `Faraday::Error` or `Nokogiri::XML::SyntaxError`.
3. **`fetch_crawled_urls`** — GET the homepage, take same-host `a[href]` links, strip
   fragments, unique, capped at `MAX_CRAWLED_LINKS` (25). **Homepage only — not a
   recursive crawler.**
4. **`record_page`** — `find_or_initialize_by(url:)`. New records get `title`,
   `meta_description` and `first_seen_at`; every record gets `last_seen_at` touched.
5. **`mark_scan`** — writes `page_scan_method`, `last_page_scan_status` and
   `last_page_scan_at` onto the `Client`.

**Never raises.** A top-level `rescue StandardError` logs a warning and marks the scan
failed, so one broken site cannot abort a batch.

Scheduling is `config/recurring.yml`, which each day at 3am enqueues one
`ScanClientSitemapJob` per `Client.kept.active`.

`ReportGenerator#sync_pages_published` then reads `SitemapPage` rows whose `first_seen_at`
falls inside the report month and **copies** url/title/description onto
`ReportPagePublished`.

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/sitemap_scanner.rb` | The whole scan: discovery, fallback, page recording |
| `app/jobs/scan_client_sitemap_job.rb` | Solid Queue wrapper; takes a client id |
| `config/recurring.yml` | The daily 3am schedule and the per-client fan-out |
| `app/models/sitemap_page.rb` | The durable per-client page record |
| `app/models/report_page_published.rb` | The per-report snapshot |
| `app/models/client.rb` | `page_scan_method`, `last_page_scan_status` enums |
| `app/services/adapters/connection_builder.rb` | Shared timeouts and retries — also used here |
| `app/services/report_generator.rb` | `sync_pages_published` reads what this produced |
| `test/services/sitemap_scanner_test.rb` | Sitemap path, crawler fallback, failure marking |

### Data

| Model / table | What it holds here |
|---|---|
| `SitemapPage` | Per client, per URL: `title`, `meta_description`, `first_seen_at`, `last_seen_at` |
| `Client` | `sitemap_url` (optional override), `page_scan_method`, `last_page_scan_status`, `last_page_scan_at` |
| `ReportPagePublished` | Per report: a **copy** of url/title/description plus a reference to the `SitemapPage` |

Invariants:

- **`first_seen_at` is written once** and never updated. It is the sole basis for which
  month a page belongs to.
- **`ReportPagePublished` copies the fields** rather than reading through the association,
  so a later title edit cannot alter a past report.
- `page_scan_method` is `sitemap` / `crawler` / `failed`; `last_page_scan_status` is
  `success` / `failed`. Both allow nil until the first scan.

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| Sitemap missing or unparseable | Falls back to crawling; usually invisible | `client.page_scan_method` becomes `crawler` |
| Site unreachable entirely | No new pages in the next report | `client.last_page_scan_status` = `failed` |
| A single page's meta fetch fails | Page recorded with empty title/description | Nothing |
| Unexpected error | Scan aborts for that client only | Rails log warning + `failed` status |
| The job never runs | No pages ever recorded | **Nowhere** — nothing detects a scan that stopped running |

### Gotchas

- **Generation never triggers a scan.** `sync_pages_published` only reads. A practice whose
  scan has never succeeded shows no pages no matter what they published.
- **A page belongs to the month it was first *seen*,** not created. Backfilling a practice
  onto the system records their whole existing site as "published" in that first scan's
  month.
- **The crawler fallback is homepage-only and capped at 25 links.** It is a safety net, not
  a site crawl — a large site without a sitemap will be badly under-reported.
- **Fragments are stripped** so a "skip to content" anchor is not counted as a separate
  page.
- **The URL is the identity.** Changing a page's address creates a second `SitemapPage` and
  it counts as newly published again.
- **`sitemap_url` is an optional per-client override**; the default is
  `<website_url>/sitemap.xml`, with `https://` prepended if `website_url` has no scheme.
- **`ScanClientSitemapJob` has no `retry_on`** deliberately — the scanner never raises, and
  the next night's run is the natural retry.

### Not built yet

- **No manual rescan trigger** in the admin panel — a developer enqueues the job.
- **No visibility of scan health.** `last_page_scan_status` is stored but never surfaced.
- **No recursive crawling** for sitemap-less sites beyond the homepage.
- **No page-removal detection.** `last_seen_at` is recorded but nothing reports pages that
  disappeared.

---

## Changing this feature

- **`first_seen_at` must never be rewritten.** It is the definition of which month a page
  belongs to, and rewriting it would retroactively change past reports.
- **`ReportPagePublished` must keep copying** title and description rather than reading
  through to `SitemapPage`.
- **The scanner must never raise.** One practice's broken site cannot be allowed to abort
  the nightly batch.
- **Keep identifying the bot honestly** in the `User-Agent`, and keep the crawl cap — this
  fetches third-party websites MSP does not own.
