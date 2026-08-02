---
title: Yext integration
slug: integration-yext
status: shipped
last_verified: 2026-08-02
related: [integrations, monthly-report, report-generation]
---

# Yext integration

> **Status:** shipped — verified against a real account · **Last verified:** 2026-08-02
>
> Yext supplies three of the report's sections: directory listings performance, AI
> visibility, and Google Business Profile activity.

---

## For everyone

### Purpose

Yext manages a practice's presence across online directories and, through its "Scout"
product, tracks how the practice appears in AI assistants. It is the widest of our five
integrations — one Yext account provides three separate report sections.

Google Business Profile data also comes through Yext rather than from Google directly. The
scope of work left that open ("Yext or GBP directly"); it was resolved in favour of Yext so
there is one integration to maintain instead of two.

### What it provides

| Report section | What Yext gives us |
|---|---|
| Citations and directory performance | How many times the practice appeared across directories, and how many actions people took |
| Google and AI search performance | Visibility score, Google and AI ranks, sentiment split, per-assistant scores |
| Google Business Profile activity | Lifetime review count and average rating, this month's reviews with owner replies, this month's posts, and the photo gallery |

### Setting it up

- **Credential:** an API key, agency-wide, entered under Connections.
- **Per practice:** the practice's Yext **entity ID**.

### When data is missing

Yext is unusual in that **its parts fail independently.** Only the citations call is
required; everything else degrades on its own.

| What fails | Effect |
|---|---|
| Citations call | The **whole** Yext result fails — no Yext data at all that month |
| AI visibility call | AI section omitted; citations and GBP still populate |
| Per-assistant scores only | AI section renders without the per-assistant breakdown |
| Reviews call | Review count and rating blank, and no reviews listed |
| Posts call | No posts listed |
| Photos call | No photos shown |

So a practice whose Yext plan does not include Scout still gets full citation and Google
Business Profile sections — the AI part simply does not appear.

### Known limits

Found by testing against a real account rather than reading documentation:

- **No split between driving directions and website clicks.** Yext exposes only a combined
  actions total, so the report omits that breakdown.
- **No breakdown of where AI citations came from** (own site, listings, reputation, third
  party). Those figures stay blank.
- **Sentiment is reported as negative and neutral only**; positive is derived as whatever
  remains.
- **Posts have no date filter on Yext's side**, so we fetch the 50 most recent and keep the
  ones from the report month. A practice posting very heavily could in principle have older
  posts pushed out of that window.
- **Photos are not really Google Business Profile photos** — they come from the practice's
  Yext entity record.

### FAQ

**Q: Our AI section is missing but everything else is there.**
A: Most likely the account does not have Scout, or the API key lacks permission for it.
Citations and GBP are unaffected by design.

**Q: The review count doesn't match what we see in Yext for the month.**
A: The count and average rating are **lifetime** figures for the practice, not the month's.
The reviews listed below them are the month's.

**Q: A review we replied to doesn't show the reply.**
A: Only a reply marked as from the business owner is captured. A reply posted by another
role is ignored.

---

## For developers

### API reference

**Base URL** `https://api.yextapis.com`
**Auth** `api_key` query parameter, plus `v=20240101` on every request
**Response envelope** every endpoint returns `{"response": {...}}`

#### 1. Analytics reports — `POST /v2/accounts/me/analytics/reports`

Used four times with different metrics. Body:

```
{ "metrics": [...], "dimensions": [...],
  "filters": { <id filter>, "startDate": "YYYY-MM-DD", "endDate": "YYYY-MM-DD" } }
```

Rows come back at `response.data` as an array of flat hashes.

| Call | Metrics | Dimensions | Filter key |
|---|---|---|---|
| Impressions | `TOTAL_LISTINGS_IMPRESSIONS` | `LOCATION_IDS` | `locationIds` |
| Engagements | `TOTAL_LISTINGS_ACTIONS` | `ENTITY_IDS` | `entityIds` |
| AI visibility | the five `SCOUT_*` metrics | `ENTITY_IDS` | `entityIds` |
| Per-assistant | `SCOUT_AI_RANK_SCORE` | `AI_MODEL`, `ENTITY_IDS` | `entityIds` |

Note the impressions call filters by **location** and the engagements call by **entity** —
that asymmetry is Yext's, not ours.

#### 2. Reviews — `GET /v2/accounts/me/reviews`

Called **twice**, deliberately:

| Purpose | Params | Reads |
|---|---|---|
| Lifetime totals | `entityIds`, `limit=1` | `response.count`, `response.averageRating` |
| This month | `entityIds`, `limit=100`, `minPublisherDate`, `maxPublisherDate` (ISO dates) | `response.reviews` |

A date-filtered call's own `count`/`averageRating` describe **only the filtered subset**,
which is why the unfiltered call exists.

#### 3. Posts — `GET /v2/accounts/me/posts`

Params `entityIds`, `limit=50`. Reads `response.posts`. **No server-side date filter
exists**, so the month filter is applied in Ruby against `postDate`.

#### 4. Photos — `GET /v2/accounts/me/entities/{entity_id}`

Reads `response.photoGallery`. This is the Knowledge Graph entity record, not a GBP
endpoint — it is covered by the same permission citations already require.

### Field mapping

**Citations** → `ReportCitation`

| Source | Column |
|---|---|
| `TOTAL_LISTINGS_IMPRESSIONS` | `total_impressions` |
| `TOTAL_LISTINGS_ACTIONS` | `total_engagements` |
| — not available | `driving_directions_count`, `website_clicks_count` (nil) |

**AI visibility** → `ReportAiVisibility`

| Source | Column | Transform |
|---|---|---|
| `SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE` | `overall_score` | — |
| `SCOUT_GOOGLE_RANK` | `google_rank` | — |
| `SCOUT_AI_RANK_SCORE` | `ai_rank` | — |
| `SCOUT_NEGATIVE_SENTIMENT_SCORE` | `sentiment_negative_pct` | **×100, rounded** — the API returns 0–1 |
| `SCOUT_NEUTRAL_SENTIMENT_SCORE` | `sentiment_neutral_pct` | ×100, rounded |
| *derived* | `sentiment_positive_pct` | `max(100 − negative − neutral, 0)` |
| — not available | `citation_*_pct` (four columns) | nil |
| `AI_MODEL` + score | `ReportAiPlatformScore` rows | platform **downcased** |

**GBP** → `ReportGbpSummary`, `GbpReview`, `GbpPost`, `GbpPhoto`

| Source | Column |
|---|---|
| `count` / `averageRating` (unfiltered) | `total_reviews` / `average_rating` |
| review `id` | `external_id` |
| review `authorName` / `rating` / `content` | `author_name` / `rating` / `body` |
| review `publisherDate` | `posted_at` — **epoch milliseconds** |
| `comments[]` where `authorRole == "BUSINESS_OWNER"` | `owner_reply_text`, `owner_replied_at` |
| post `postTitle` / `text` / `postDate` | `title` / `description` / `published_at` |
| photo `image.url` / `description` | `image_url` / `caption` |

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/yext_adapter.rb` | All four concerns: citations, AI visibility, reviews/posts/photos |
| `app/services/adapters/base.rb` | `degrade` — the per-sub-fetch failure isolation this adapter leans on |
| `app/services/report_generator.rb` | `sync_yext` fans the one result into three writes |
| `test/services/adapters/yext_adapter_test.rb` | Real response shapes for every endpoint |

### Data

Writes into `ReportCitation`, `ReportAiVisibility`, `ReportAiPlatformScore`,
`ReportGbpSummary`, `GbpReview`, `GbpPost`, `GbpPhoto`. See
[report-generation](report-generation.md) for how each is persisted.

### Failure modes

| Failure | Result |
|---|---|
| Citations call fails | `Result.failure` — the whole Yext step warns and writes nothing |
| Any other call fails | That sub-result degrades to its default (`nil`, `[]`, or `{}`) and the rest succeeds |
| Malformed JSON | **Not** caught — `JSON::ParserError` is not a `Faraday::Error`, so it fails the whole run |

### Gotchas

- **Rows are keyed inconsistently.** Yext sometimes keys a metric by its raw ID
  (`TOTAL_LISTINGS_ACTIONS`) and sometimes by a display name (`Total Listings Impressions`)
  — **within the same account.** `metric_value` sidesteps this by taking whatever value is
  left after removing the known dimension keys. Do not "simplify" it to a direct lookup.
- **Sentiment metrics are 0–1 fractions**, not percentages.
- **`publisherDate` is epoch milliseconds**, not seconds and not ISO.
- **The two reviews calls are not redundant.** Removing the unfiltered one would silently
  turn lifetime totals into month-only totals.
- **Post filtering is client-side and capped at 50.** If Yext ever adds a date filter, move
  it server-side.
- **Only citations is required.** That asymmetry is deliberate — do not wrap the other calls
  in the same required-ness.
- **`SCOUT_GOOGLE_RANK`'s scale is unconfirmed** — observed `0.0` for an account with no
  ranked keywords. Treat with suspicion until seen on a richer account.
- **Photos are entity-record photos**, so a practice managing GBP photos outside Yext will
  show none.

### Not built yet

- No pagination on reviews (capped at 100) or posts (50).
- Citation source breakdown and the directions/clicks split are unavailable from Yext, so
  four `ReportAiVisibility` columns and two `ReportCitation` columns are always nil.

---

## Changing this feature

- **Keep citations required and everything else degradable.** A practice without Scout must
  still get citations and GBP.
- **Never assume a metric's key.** Yext's inconsistent keying is real and observed.
- **Keep the unfiltered reviews call** for lifetime totals.
