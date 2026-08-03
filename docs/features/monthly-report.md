---
title: Monthly report
slug: monthly-report
status: shipped
last_verified: 2026-08-02
related: [report-generation, integrations, page-scan]
---

# Monthly report

> **Status:** shipped · **Last verified:** 2026-08-02
>
> The monthly SEO report a dental practice receives — one private web page showing what
> their search visibility did last month.

---

## For everyone

### Purpose

Every month each practice gets a report showing how their online presence performed:
website traffic, appointments booked, how they appear in online directories and in AI
assistants, where their keywords rank, what happened on their Google Business Profile,
and which pages were added to their site. It exists so a practice can see what they are
paying for without needing to understand SEO.

The report is the product. Everything else in this system exists to produce it.

### Who uses it

**The practice** — usually the dentist or office manager. They open a link and read the
page. There is no login and no account to manage.

Nobody sees a practice's report unless they hold that practice's link.

### How it behaves

1. The practice receives a link. It is unique to them, unguessable, and permanent for
   that month.
2. Opening it shows that month's report, headed by the practice name and the month.
3. If earlier months exist, a dropdown in the header switches between them. Only months
   already generated appear — never the month in progress.
4. The page is read top to bottom. Nothing to click beyond the month switcher.

**The link is the only key.** Anyone holding it can read that report, so treat it like a
password. Search engines are instructed not to index these pages.

The report is designed for a phone, which is how most practices open it.

**The first month is different.** A practice's first report replaces the month-over-month
summary with a "baseline month" introduction describing the setup work done that month —
website optimisation, directory listings, Google Business Profile setup, keyword
research — because there is nothing to compare against yet. It also ends with a
partnership note.

### What the report contains

| Section | Shows |
|---|---|
| Highlights | A short written summary of the month. Omitted on a first report, and whenever there is nothing genuinely positive to say |
| Website traffic and conversions | Visits, where they came from, appointments booked, estimated revenue |
| Citations and directory performance | How often the practice appeared across online directories, and how often people acted |
| Google and AI search performance | How the practice shows up in AI assistants. Only for practices enrolled in AI SEO |
| Keyword performance | Where tracked search terms rank, and what moved since last month |
| Google Business Profile activity | Reviews, posts and photos from the month |
| Pages published | New pages added to the practice's website that month |

### When data is missing

**This is the section clients ask about.** The report is built to still render when a data
source is unavailable. A missing source produces a placeholder, never a broken page and
never an invented number.

| What's missing | What the client sees |
|---|---|
| The practice has no appointment scheduler with us | Appointments and estimated revenue show **?**, with a note that connecting the scheduler will populate them |
| Website analytics not connected for this practice | Visits show **—** with "Google Analytics isn't connected yet for this practice", and the traffic-sources breakdown is hidden |
| The practice isn't enrolled in AI SEO | The "Google and AI Search Performance" section is omitted entirely, not shown empty |
| Directory data unavailable that month | Citation figures blank; nothing else affected |
| Keyword data unavailable, or terms not tracked | The keyword table is empty; nothing else affected |
| No pages added to the site that month | The pages section shows an empty state |
| Nothing genuinely positive to summarise | The highlights banner is omitted rather than padded with filler |
| The directory provider gives no split between driving directions and website clicks | That breakdown is omitted; the combined engagement total still shows |

A missing section is missing quietly. The report never shows an error.

### FAQ

**Q: Can someone else see our report?**
A: Only if they have your link. There is no login, and the link contains a long random
code that cannot be guessed. Treat it like a password. Search engines are told not to
index it.

**Q: Why do appointments and revenue show a question mark?**
A: Those come from our appointment scheduler. If the practice is not using it, we have no
way to count them. Connecting it populates them from the next report onward.

**Q: Why doesn't our report have the AI search section?**
A: It only appears for practices enrolled in AI SEO. If a practice enrols later it appears
from that month forward — past reports are never rewritten.

**Q: Can we see this month's report partway through the month?**
A: No. Reports cover complete calendar months, so one exists only once the month has
ended.

**Q: The numbers in an old report look wrong now. Can they be corrected?**
A: Past reports are deliberately frozen as a record of what was true at the time. They are
not recalculated when data changes later.

**Q: Who wrote the highlights paragraph?**
A: It is generated automatically from that month's figures and may only reference numbers
already in the report. If there is nothing positive to say, it is left out rather than
filled with generic text.

**Q: We added pages to our site but the pages section is empty.**
A: Pages are discovered from the site's sitemap on a daily scan. A page added late in the
month is picked up, but a site with no reachable sitemap may fall back to a limited scan.
See [page-scan](page-scan.md).

---

## For developers

### How it works

One controller action, deliberately thin:

1. **Route** — `GET /reports/:access_token`, no authentication; `ReportsController` skips
   the app-wide `authenticate_admin!`.
2. **Load** — the `MonthlyReport` is found by `access_token` with a large `includes`
   preloading roughly a dozen associations. A miss raises
   `ActiveRecord::RecordNotFound`, handled into a 404 rendering `reports/not_found`.
3. **Wrap** — the record is wrapped in `ReportPresenter`, which owns every computed number
   and every availability predicate.
4. **Render** — `reports/show` renders under `layout "report"` (which sets
   `noindex,nofollow`) composing the section partials in fixed order. Sections gate
   themselves on presenter predicates: `first_report?`, `ai_visibility_available?`,
   `ga4_available?`, `ghl_connected?`.

Views contain no queries and no arithmetic. Anything computed is a presenter method.

### Key files

| Path | Role in this feature |
|---|---|
| `config/routes.rb` | The `public_report` route, keyed by `access_token` |
| `app/controllers/reports_controller.rb` | Loads and preloads the report, handles 404 |
| `app/presenters/report_presenter.rb` | Every computed figure and availability predicate |
| `app/views/layouts/report.html.erb` | Public layout; sets `noindex,nofollow` |
| `app/views/reports/show.html.erb` | Section composition and ordering |
| `app/views/reports/_header.html.erb` | Practice name, month switcher |
| `app/views/reports/_highlights.html.erb` | The generated banners |
| `app/views/reports/_first_report_intro.html.erb` | Baseline-month narrative |
| `app/views/reports/_traffic.html.erb` | Visits, appointments, revenue |
| `app/views/reports/_citations.html.erb` | Directory impressions and engagements |
| `app/views/reports/_ai_visibility.html.erb` | AI search performance |
| `app/views/reports/_keyword_performance.html.erb` | Rankings and movement |
| `app/views/reports/_gbp_activity.html.erb` | Reviews, posts, photos |
| `app/views/reports/_pages_published.html.erb` | New website pages |
| `app/views/reports/_partnership_cta.html.erb` | First-report closing note |
| `app/views/reports/_footer.html.erb` | MSP contact details at the page foot |
| `app/views/shared/_stat_card.html.erb` | Shared figure tile, incl. the `hero` treatment — also used by the Dashboard |
| `app/views/reports/_section_card.html.erb` | Shared section heading block |
| `app/views/reports/not_found.html.erb` | 404 page |
| `app/helpers/reports_helper.rb` | `report_icon` / `icon_badge`, keyword styling |
| `app/javascript/controllers/month_switcher_controller.js` | Navigates on `<select>` change |

### Data

Read-only here — this feature writes nothing. See
[report-generation](report-generation.md) for how the rows are produced.

| Model / table | What it holds here |
|---|---|
| `MonthlyReport` | `report_month`, `access_token`, `generated_at`, `is_first_report` |
| `ReportTraffic` | Visits by source, appointments, revenue, `ghl_data_status` |
| `ReportCitation` | Directory impressions/engagements plus the previous month's figures |
| `ReportAiVisibility` + `ReportAiPlatformScore` | AI scores, sentiment split, per-platform scores |
| `ReportGbpSummary`, `GbpPost`, `GbpReview`, `GbpPhoto` | Google Business Profile activity |
| `ReportKeywordRanking` | `position` and `previous_position` per tracked keyword |
| `ReportPagePublished` | Pages first seen during the report month |
| `ReportHighlight` | Generated banner text plus the model used |

Invariants that matter here:

- `access_token` is unique at the database level and generated as
  `SecureRandom.urlsafe_base64(32)`.
- `(client_id, report_month)` is unique **as a database index**, not just a validation.
- A report only appears in the month switcher once `generated_at` is set, which is why the
  in-progress month can never be listed.
- `ReportAiVisibility` **presence** — not `client.ai_seo_enrolled?` — decides whether the
  AI section renders, so a later enrolment change cannot rewrite history.
- `ReportPagePublished` stores its own `url`/`title`/`description` rather than reading
  through to `SitemapPage`, so editing a page title later does not alter a past report.

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| Unknown or truncated token | 404, "Report not found" | Nothing — expected traffic |
| A data section absent | Placeholder or omitted section (see the table above) | `report_generation_logs.error_log`, from when it was generated |
| A view raises | Standard 500 | Rails log only — **there is no error-tracking service** |

### Gotchas

- **`.sort_by`, not `.order`, in the presenter.** `keyword_rows`, `gbp_posts` and
  `gbp_reviews` sort in Ruby because the rows are already loaded by the controller's
  `includes`. Switching to `.order` issues a fresh query and silently defeats the preload
  on the app's hottest page.
- **Adding a section means adding its association to that `includes`**, or the report
  gains an N+1.
- **The token is a path segment, not a parameter**, so `filter_parameters` does not redact
  it — full report URLs land in production logs. See CLAUDE.md → Security.
- **Tailwind only compiles class names it can see literally.** Never interpolate a colour
  into a class string in these views.
- **Icons never go inline.** New icons are added to `ICON_INNER` in `reports_helper.rb`.
- **`ghl_data_status` has three values**, not two: `connected`, `not_connected` (no link
  configured) and `access_unavailable` (link exists but the call failed). The report
  currently renders the latter two identically.

### Not built yet

- **Emailing the report.** `SendLog` and `MonthlyReport#emailed_at` exist, and `emailed_at`
  is intended as the duplicate-send guard, but there is no mailer. Note
  `config.action_mailer.default_url_options` is still `example.com`. `SendLog#status` already
  has a `held` value (distinct from `failed`) for a recoverable block — e.g. the destination
  credential being rejected — ready for whichever job ends up writing these rows.
- **Accessibility gaps**: subsection titles are styled `<p>` rather than `<h3>`, and GBP
  photo `alt` falls back to empty when a caption is absent.
- **No direct tests for `ReportPresenter`.** It is covered incidentally by controller tests
  rendering the views; its `nil`-guard branches are largely unexercised.

---

## Changing this feature

- **Never render a report for the current, incomplete month.**
- **Never retroactively recompute a past report.** Each is frozen at generation. This is
  why AI-visibility availability and published-page details are stored per report rather
  than derived.
- **Degrade, never fail.** A missing integration renders a placeholder. Do not introduce a
  path where an absent source produces an error page or a blank report.
- **Never make report URLs guessable** — no sequential IDs, no practice-name slugs.
- **Highlight text may only reference numbers present in that month's data**, 2–3
  sentences, omitted entirely rather than padded.
