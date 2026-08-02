---
title: Data model
slug: data-model
kind: reference
last_verified: 2026-08-02
---

# Data model

Every table, what it holds, and the constraints that matter. Reference material — see the
[feature documents](../README.md#feature-documents) for how each is used.

**22 tables in three groups:** the practice and its configuration, the frozen monthly
report and its sections, and the operational logs.

---

## Conventions across the schema

- **UUID string primary keys on the two root tables.** `clients` and `monthly_reports` use
  `t.string :id, limit: 36, default: -> { "gen_random_uuid()" }`, with `HasUuidPrimaryKey`
  also setting one before create. Everything else uses ordinary bigint ids.
- **Foreign keys are declared by hand.** `t.string :client_id, limit: 36` plus a separate
  `add_foreign_key`, not `t.references`.
- **`Report*` children key on `report_id`**, not the inferred `monthly_report_id`, so every
  association declares `foreign_key: :report_id` and `class_name: "MonthlyReport"`.
- **Money and percentages are `decimal`** with explicit precision, never float.
- **Enums are validated** (`validate: true`), so an unexpected value raises rather than
  silently storing.
- **Real invariants are database indexes**, not only validations.

---

## Group 1 — The practice and its configuration

### `clients`

The practice. UUID primary key. Soft-deleted via `discard`.

| Column | Notes |
|---|---|
| `name` | Required. **Overwritten from HubSpot** on every report run |
| `address`, `phone`, `logo_url` | `phone` and `logo_url` are **never written or read** |
| `website_url` | Drives the page scan's sitemap lookup **and** SEMrush's URL mask |
| `sitemap_url` | Optional override; defaults to `<website_url>/sitemap.xml` |
| `onboarding_status` | Enum: `pending` / `active` / `offboarded` |
| `onboarded_at` | Date |
| `ai_seo_enrolled` | Default false. **Decides whether AI visibility is captured** |
| `page_scan_method` | Enum, nil-allowed, prefixed `page_scan`: `sitemap` / `crawler` / `failed` |
| `last_page_scan_status` | Enum, nil-allowed, prefixed `last_page_scan`: `success` / `failed` |
| `last_page_scan_at` | Written by the nightly scan |
| `discarded_at` | Indexed. **No default scope** — `Client.all` includes discarded rows |

### `client_keywords`

Search terms tracked for a practice.

| Column | Notes |
|---|---|
| `keyword` | Required. Matched to SEMrush **case-insensitively** |
| `intent` | Free string: `C`, `T`, `I`, `N`, or a combination like `"I C"` |
| `keyword_difficulty`, `serp_features` | Rendered in the report but **never populated by any adapter** — seed data only |
| `active` | **Default true**; only active keywords are looked up |

### `client_service_links`

Per practice, per service: the identifier and optional credential override.

| Column | Notes |
|---|---|
| `service` | FK to `services.key` |
| `external_id` | The practice's ID inside that service |
| `override_credentials` | **Encrypted.** JSON blob; blank means use the agency credential |
| `credential_status`, `last_verified_at` | **Never written** |

Unique on `(client_id, service)`. **The existence of a `ghl` row is the record of whether a
practice uses our scheduler.**

### `services`

Lookup table. **Primary key is the `key` string itself** (`self.primary_key = "key"`), which
backs the foreign keys on `agency_connections` and `client_service_links` — replacing what
was the same hardcoded list duplicated across two enum declarations.

Seeded both by its migration and by `db/seeds.rb`, so a schema-loaded database still gets
the rows.

### `agency_connections`

One row per service, holding the agency-wide credential.

| Column | Notes |
|---|---|
| `service` | FK to `services.key`, **unique** |
| `encrypted_credentials` | **Encrypted.** JSON blob; shape differs per service |
| `credential_status` | Enum, nil-allowed, prefixed `credential`: `active` / `expiring_soon` / `expired` / `invalid`. **Never written** |
| `expires_at`, `last_verified_at` | **Never written** |

The `credential` prefix exists because a bare `invalid` value would override Active Record's
own `#invalid?`.

### `sitemap_pages`

Every page ever seen on a practice's website. Durable, not per report.

| Column | Notes |
|---|---|
| `url` | Required. Unique per client. **The page's identity** — a changed URL is a new page |
| `title`, `meta_description` | Captured **once**, at first discovery |
| `first_seen_at` | **Written once, never updated.** Defines which month a page counts as published |
| `last_seen_at` | Touched on every scan. Recorded but never reported on |

### `admin_users`

MSP staff.

| Column | Notes |
|---|---|
| `email` | Required, unique index, downcased before validation |
| `password_digest` | `has_secure_password`; minimum 8 characters |
| `role` | Enum: `admin` (can write) / `support` (read-only) |

---

## Group 2 — The report and its sections

### `monthly_reports`

One per practice per month. UUID primary key.

| Column | Notes |
|---|---|
| `report_month` | Required. Always the **first of the month** |
| `access_token` | Required, **unique index**. `SecureRandom.urlsafe_base64(32)`. This is the only thing protecting the report |
| `is_first_report` | Set at creation when no earlier report exists |
| `generated_at` | Only a report with this set appears in the month switcher |
| `emailed_at` | Intended duplicate-send guard. **Never written — nothing emails** |

**Unique index on `(client_id, report_month)`** — this is what makes the generator's
`find_or_create_by!` race-safe.

Every section below is `has_one` (or `has_many`) on the report and is destroyed and
recreated on each generation run, which is what makes generation idempotent.

### `report_traffics` — one per report

| Column | Source |
|---|---|
| `total_visits`, `unique_visitors`, `pages_per_visit` | GA4 |
| `organic_visits`, `direct_visits`, `referral_visits`, `paid_visits` | GA4, by channel. **`paid_visits` sums five paid channels** |
| `appointments_booked`, `estimated_revenue` | GHL. Revenue is `decimal(12,2)` |
| `ghl_data_status` | Enum: `connected` / `not_connected` / `access_unavailable` |
| `previous_*` (seven columns) | **Never written.** Intended for month-over-month traffic movement |

`total_visits` being present is what `ReportPresenter#ga4_available?` keys on — that one
column decides whether the traffic block renders or shows a placeholder.

### `report_citations` — one per report

`total_impressions`, `total_engagements` from Yext, plus `previous_impressions` and
`previous_engagements` carried from last month's report.

`driving_directions_count` and `website_clicks_count` exist but are **always nil** — Yext
exposes no such split.

### `report_ai_visibilities` — one per report

`overall_score`, `previous_score`, `google_rank`, `ai_rank`, and the three sentiment
percentages (`positive` derived as the remainder).

The four `citation_*_pct` columns are **always nil** — no such metric was found in Yext's
catalogue.

**The row's existence, not `client.ai_seo_enrolled?`, decides whether the report's AI
section renders.** That is what freezes enrolment per report so a later change cannot
rewrite history.

### `report_ai_platform_scores` — many per AI visibility row

`platform` and `score`. **Deliberately not an enum** — Yext returns whatever model names it
likes (`GEMINI`, `PERPLEXITY`) and new ones appear over time.

### `report_gbp_summaries` — one per report

`total_reviews` and `average_rating` (`decimal(3,2)`) are **lifetime** figures, not the
month's. `new_positive_reviews` / `new_negative_reviews` are derived at write time by
counting the month's reviews. `needs_photos` is set when no photos synced.

### `gbp_reviews` — many per report

`author_name`, `rating`, `body`, `posted_at`, plus `owner_reply_text` and
`owner_replied_at` from the review's business-owner comment.

`sentiment` is an enum derived at write time from the rating (≤2 negative, 3 neutral, ≥4
positive); `needs_action` is set for ratings ≤2. **These thresholds are provisional** — the
scope of work left them undefined.

Unique on `(report_id, external_id)`, nil-allowed.

### `gbp_posts` — many per report

`title`, `description`, `published_at`. Filtered to the report month **in Ruby**, since the
Yext posts endpoint has no server-side date filter.

### `gbp_photos` — many per report

`image_url`, `caption`. Sourced from the Yext entity's photo gallery, not a GBP endpoint.

### `report_keyword_rankings` — many per report

| Column | Notes |
|---|---|
| `keyword_id` | FK to `client_keywords` |
| `position` | Nil when not ranked — **never 0**, which would sort as the best rank |
| `previous_position` | **Our own record**, carried from last month's report, not from SEMrush |
| `potential_traffic` | `decimal(10,2)`. An approximation |
| `growth` | `decimal(10,2)`. **Never written** — seed data only |

Unique on `(report_id, keyword_id)`.

### `report_pages_published` — many per report

References a `sitemap_page` but **copies** `url`, `title` and `description` onto itself, so
a later edit to the page's title cannot alter a past report.

Note the table name is plural-of-plural; the model sets `self.table_name` explicitly.

### `report_highlights` — one per report

`summary_text`, `ai_seo_summary_text`, `generated_at`, and `model_used` — the last so a
future model change stays traceable in reports already sent. No row is written when both
strings are blank.

---

## Group 3 — Operational logs

### `report_generation_logs`

One row per generation attempt, success or failure.

| Column | Notes |
|---|---|
| `status` | Enum: `success` / `failed` |
| `attempted_at` | Required |
| `error_summary` | The fatal error, or the first warning |
| `error_log` | **All** per-service warnings, newline-joined — **populated even on success** |

Indexed on `(monthly_report_id, attempted_at)`.

**This is the system's only observability.** There is no error-tracking service, so a
degraded section is discoverable here and nowhere else. Read `error_log` even when the
status is `success`.

### `send_logs`

Same shape (`status`, `attempted_at`, `error_message`) for report emails. **No rows are ever
written — nothing emails yet.**

---

## Model files

Every table's model, so grepping this directory for a model path lands here.

| Table | Model file |
|---|---|
| `clients` | `app/models/client.rb` |
| `client_keywords` | `app/models/client_keyword.rb` |
| `client_service_links` | `app/models/client_service_link.rb` |
| `services` | `app/models/service.rb` |
| `agency_connections` | `app/models/agency_connection.rb` |
| `sitemap_pages` | `app/models/sitemap_page.rb` |
| `admin_users` | `app/models/admin_user.rb` |
| `monthly_reports` | `app/models/monthly_report.rb` |
| `report_traffics` | `app/models/report_traffic.rb` |
| `report_citations` | `app/models/report_citation.rb` |
| `report_ai_visibilities` | `app/models/report_ai_visibility.rb` |
| `report_ai_platform_scores` | `app/models/report_ai_platform_score.rb` |
| `report_gbp_summaries` | `app/models/report_gbp_summary.rb` |
| `gbp_reviews` | `app/models/gbp_review.rb` |
| `gbp_posts` | `app/models/gbp_post.rb` |
| `gbp_photos` | `app/models/gbp_photo.rb` |
| `report_keyword_rankings` | `app/models/report_keyword_ranking.rb` |
| `report_pages_published` | `app/models/report_page_published.rb` |
| `report_highlights` | `app/models/report_highlight.rb` |
| `report_generation_logs` | `app/models/report_generation_log.rb` |
| `send_logs` | `app/models/send_log.rb` |

Shared behaviour lives in `app/models/concerns/has_uuid_primary_key.rb`, included by
`Client` and `MonthlyReport`. It sets `id` before create even though PostgreSQL's
`gen_random_uuid()` default would suffice — kept as an explicit, adapter-independent
guarantee, and as a fallback for inserts that bypass Rails.

---

## Files deliberately not documented

For completeness, so their absence reads as a decision rather than an oversight:

| File | Why |
|---|---|
| `app/models/application_record.rb`, `app/jobs/application_job.rb`, `app/mailers/application_mailer.rb` | Stock Rails base classes, unmodified |
| `app/javascript/application.js`, `app/javascript/controllers/application.js`, `app/javascript/controllers/index.js` | Stock importmap and Stimulus wiring |
| `app/views/layouts/mailer.html.erb`, `app/views/layouts/mailer.text.erb` | Stock, and nothing sends mail yet |
| `app/javascript/controllers/hello_controller.js` | **Scaffolding cruft** — eagerly registered, referenced by no view. Delete it |
| `app/views/pwa/manifest.json.erb`, `app/views/pwa/service-worker.js` | Present, but the routes serving them are commented out in `config/routes.rb`. **Either wire them up or remove them** — don't leave a third state |

---

## Things worth knowing before changing this

- **Never rewrite `first_seen_at` on a `sitemap_page`.** It defines which month a page
  belongs to, and rewriting it retroactively changes past reports.
- **Never make `report_pages_published` read through to `sitemap_pages`.** The copy is the
  point.
- **`Client.all` includes discarded practices.** Use `Client.kept` anywhere a soft-deleted
  practice must not appear.
- **A new report section means a new association in the report preload list**, or the public
  page gains an N+1.
- **Columns that exist but are never written**: `clients.phone`, `clients.logo_url`, all
  seven `report_traffics.previous_*`, `report_keyword_rankings.growth`,
  `client_keywords.keyword_difficulty` and `serp_features` (outside seeds),
  `monthly_reports.emailed_at`, both `credential_status` columns, `expires_at`,
  `last_verified_at`, and everything in `send_logs`. Treat them as intent, not as data.
