---
title: Report generation
slug: report-generation
status: partial
last_verified: 2026-08-05
related: [monthly-report, integrations, page-scan, admin-panel]
---

# Report generation

> **Status:** partial — generation is scheduled and safe to re-run, but nothing emails
> the result and nothing alerts on failure · **Last verified:** 2026-08-05
>
> The monthly process that collects a practice's data from every external service and
> freezes it into that month's report.

---

## For everyone

### Purpose

A report is not assembled when someone opens it. Once a month, per practice, the system
calls each external service, writes the results down, and marks the report as generated.
Everything the practice sees afterwards is that stored snapshot.

Storing rather than fetching live is deliberate. It means a report opened a year later
shows exactly what was true when it was produced, and a service being down today cannot
change last year's numbers.

### Who uses it

**MSP staff**, indirectly. Nobody in the practice triggers this. Today it is a command a
developer runs — see [MSP-GUIDE](../MSP-GUIDE.md#generate-a-report).

### How it behaves

1. Someone starts generation for one practice and one completed month.
2. The system refuses immediately if the month is the current month or in the future.
3. It finds or creates that month's report, marking it as the practice's first if no
   earlier report exists.
4. It calls each source in turn — practice details, website traffic and appointments,
   directories and AI visibility and Google Business Profile, keyword rankings — then
   collects the pages found on the practice's site that month.
5. **HubSpot, Google Analytics, Yext, and SEMrush are required.** If any of them fails, the
   whole run stops immediately — the report is marked failed and nothing is produced for
   that month. The online scheduler (GHL) and AI SEO are the two exceptions: a practice
   that doesn't use them simply has that section omitted, same as always — but a practice
   that *does* use one of them needs it to actually work, same as the required four.
6. Unless it is a first report, a short written summary is generated from the figures now
   stored.
7. The report is marked generated, and the attempt is recorded.

**Re-running is always safe.** Generating again for the same practice and month replaces
that month's data rather than duplicating it. So the fix for a failed or partial run is
simply to fix the cause and run it again.

### When data is missing

This is where the report's degraded states are decided — and today, there are only two of
them, both opt-in.

| What's missing | What happens |
|---|---|
| HubSpot, Google Analytics, Yext, or SEMrush fails, for any client | Generation **stops**. The whole run fails, nothing is produced for that month, and the failure is recorded |
| The practice has no appointment scheduler linked | Recorded as "not connected" without ever calling the scheduler service — the report generates normally |
| The scheduler **is** linked but the call fails | Generation **stops**, same as the four required services — a linked scheduler is expected to work |
| The practice is not enrolled in AI SEO | That section is omitted entirely — the report generates normally |
| The practice **is** enrolled but no AI visibility data comes back | Generation **stops** — an enrolled practice is expected to have this data |
| The summary-writing service is unavailable | The report is produced with no highlights banner (this one still degrades — it isn't one of the five core services) |

The design: **every practice is assumed to have HubSpot, Google Analytics, Yext, and
SEMrush properly configured — a failure there is something to fix, not a placeholder to
render.** GHL and AI SEO are opt-in features, not universal ones — not using them is a
normal, expected state, but once a practice *is* opted in, that source is held to the same
"must work" bar as the other four.

### FAQ

**Q: How often does this run?**
A: `EnqueueMonthlyReportsJob` runs on the 1st of every month at 4am and starts generation
for every active practice's last completed month. See
[jobs-and-schedules](../reference/jobs-and-schedules.md).

**Q: What if we run it twice for the same month?**
A: Nothing bad. The second run replaces the first month's data.

**Q: Can we regenerate an old report to pick up corrected data?**
A: Technically yes, and it will overwrite that month. But reports are meant to be frozen
records — think carefully before changing what a practice has already been shown.

**Q: How do we know it worked?**
A: Every attempt is recorded with its status and warnings. Nothing alerts anyone, so it
must be checked. See [MSP-GUIDE](../MSP-GUIDE.md#check-whether-a-report-worked).

---

## For developers

### How it works

`ReportGenerator` is the orchestrator, instantiated with a client and a month and invoked
with `#call`. Its body is a table of contents:

1. **Guard** — raises `MonthNotCompleteError` if `month >= Date.current.beginning_of_month`.
2. **`find_or_create_report`** — delegates to `Client#find_or_create_monthly_report`, which
   sets `is_first_report` by comparing this report's month against the client's
   `onboarded_at` (synced from HubSpot's `gmb_seo_start_date` — see
   [integration-hubspot](integration-hubspot.md)), falling back to "no earlier report
   exists" only if `onboarded_at` isn't known yet. Shared with `EnqueueMonthlyReportsJob`,
   which calls the same method to create the row **queued** before this job ever runs — see
   [jobs-and-schedules](../reference/jobs-and-schedules.md).
3. **`mark_generating`** — sets `generation_status: "generating"` and bumps `attempt_count`.
4. **`sync_hubspot`** — updates the `Client` record itself from HubSpot (name, address,
   website, onboarding status, AI SEO enrolment). HubSpot is the source of truth for these.
   **Mandatory** — a failed result raises `ReportGenerator::AdapterFailureError`.
5. **`sync_traffic`** — GA4 for visits (**mandatory**, raises on failure), then GHL for
   appointments/revenue **only if a GHL `ClientServiceLink` exists**; otherwise sets
   `ghl_data_status: "not_connected"` without an API call. If a GHL link *does* exist, that
   call is mandatory too — a failure raises the same way GA4's does.
6. **`sync_yext`** — one Yext call fanning into three writes: citations, AI visibility, GBP
   activity. **Mandatory** — a failed result raises. Within it, `sync_ai_visibility` is a
   second, independent mandatory check: skipped entirely if the client isn't
   `ai_seo_enrolled?`, but raises if they are enrolled and Yext's response has no AI
   visibility payload.
7. **`sync_keywords`** — SEMrush rankings, carrying last month's `position` forward into
   this month's `previous_position`. **Mandatory** — a failed result raises.
8. **`sync_pages_published`** — reads `SitemapPage` rows whose `first_seen_at` falls in the
   month. Does **not** trigger a scan; see [page-scan](page-scan.md).
9. **`sync_highlights`** — skipped for first reports; calls `HighlightGenerator`. Not one of
   the five core services, so still degrades silently on failure (see Gotchas).
10. **`mark_ready`** — stamps `generated_at`, sets `generation_status: "ready"`, then
    `log_attempt(status: "success")` — which both writes a `ReportGenerationLog` row and
    logs a line to `Rails.logger.info`.

`Adapters::Base#call` still never raises — it always returns a `Result`, success or
failure (see [Adapters](../../CLAUDE.md#adapters)). What changed is what `ReportGenerator`
does with a failure: for the four required services (plus a *configured* GHL link, plus an
*enrolled* AI SEO client), it raises its own `ReportGenerator::AdapterFailureError` rather
than degrading. That, like any other unexpected exception, is caught by the single
top-level `rescue StandardError`, which sets `generation_status: "failed"`, logs the
attempt (`Rails.logger.error` + a `ReportGenerationLog` row), and **re-raises** — it never
swallows.

Idempotency is achieved by replace-then-create per child collection
(`report.gbp_posts.destroy_all` then recreate) and `find_or_initialize_by` for keyword
rankings.

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/report_generator.rb` | The orchestrator — every step lives here |
| `app/services/highlight_generator.rb` | Writes the two summary banners via Anthropic's API |
| `app/services/concerns/monthly_range.rb` | Shared "calendar month as a Range" helper |
| `app/jobs/generate_monthly_report_job.rb` | Solid Queue wrapper; takes IDs, not records |
| `app/jobs/enqueue_monthly_reports_job.rb` | Monthly fan-out — one `GenerateMonthlyReportJob` per active client |
| `app/models/report_generation_log.rb` | One row per attempt, success or failure |
| `app/services/sync_client_from_hubspot.rb` | `sync_hubspot`'s real work — also used standalone by `EnqueueHubspotSyncJob`, see [integration-hubspot](integration-hubspot.md) |
| `app/models/client.rb` | `find_or_create_monthly_report` — the one place `is_first_report` is decided |
| `lib/tasks/real_client.rake` | `reports:generate_real` — how generation is actually invoked today |
| `test/services/report_generator_test.rb` | The reference test: happy path, idempotency, a failure test per mandatory service, the two opt-in degraded states |
| `test/jobs/enqueue_monthly_reports_job_test.rb` | Covers the active/pending/offboarded/already-generated fan-out rules |
| `test/models/client_test.rb` | `is_first_report` from `onboarded_at`, including the backfill case that motivated it |

### Data

| Model / table | What it holds here |
|---|---|
| `MonthlyReport` | Created queued (often by `EnqueueMonthlyReportsJob`, ahead of this running); `generation_status` moves queued → generating → ready/failed; `attempt_count` bumped every attempt; `generated_at` stamped on success |
| `Client` | **Written** by `sync_hubspot` — this is the one place client fields are updated |
| `ReportTraffic` | Built or updated in place, then saved once |
| `ReportCitation`, `ReportAiVisibility`, `ReportGbpSummary` | Destroyed and recreated |
| `GbpPost`, `GbpReview`, `GbpPhoto` | `destroy_all` then recreated |
| `ReportKeywordRanking` | `find_or_initialize_by(keyword_id:)` then updated |
| `ReportPagePublished` | `destroy_all` then recreated from `SitemapPage` |
| `ReportHighlight` | Destroyed and recreated, storing `model_used` |
| `ReportGenerationLog` | Appended per attempt: `status`, `attempted_at`, `error_summary`, `error_log` |

Invariants:

- `(client_id, report_month)` unique index makes the `find_or_create_by!` race-safe.
- `previous_position` is **our own** historical record, carried forward from last month's
  report — it is not read from SEMrush.
- Review sentiment is derived at write time from the rating (≤2 negative, 3 neutral, ≥4
  positive) and `needs_action` is set for ratings ≤2. These thresholds are provisional.

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| HubSpot, GA4, Yext, or SEMrush fails | Nothing — the run aborts, report stays ungenerated | `report_generation_logs` status `failed`, `error_summary`/`error_log` naming which service |
| A configured GHL link fails, or an AI-SEO-enrolled client's Yext response has no AI data | Same as above — these are mandatory once opted in | Same as above |
| Anthropic unavailable or no API key | No highlights banner | Rails log warning only — this is the one source that still degrades silently |
| Any other unexpected exception (a bug, not an adapter failure) | Nothing — the run aborts, report stays ungenerated | `report_generation_logs` status `failed`, plus the raised error |
| Nobody runs generation at all | No report exists for that month | **Nowhere** — nothing detects a missing report |

That last row is the biggest operational gap in the system.

### Gotchas

- **`sync_hubspot` writes to `Client`.** Editing a practice's name or AI SEO enrolment
  locally is pointless — an hourly job and the next generation run both overwrite it from
  HubSpot.
- **AI visibility is frozen per report** deliberately. It is written only when
  `client.ai_seo_enrolled?` **at run time**, and afterwards the report renders based on the
  row existing — so an enrolment change never rewrites history.
- **`is_first_report` is decided by `onboarded_at`, not report history, specifically to
  survive a backfill.** A client onboarded in February but only backfilled starting in June
  correctly gets `is_first_report: false` for June — there's no earlier report, but June
  still isn't their onboarding month. Falls back to "no earlier report" only when
  `onboarded_at` is unknown.
- **`sync_gbp_activity` does four things** despite its name (summary, posts, reviews,
  photos) and derives review sentiment inline. It is a known violation of the unit-function
  rule in CLAUDE.md — split it when you next touch it, don't add to it.
- **`sync_pages_published` never scans.** It only reads what `SitemapScanner` already
  found. A practice whose scan has never run shows no pages regardless of what they
  published.
- **The highlight generator is not part of the warnings channel.** Its failures go to the
  Rails log only, so a persistently missing banner will not show up in `error_log`.
- **`GenerateMonthlyReportJob` takes `(client_id, year, month)`** — IDs, not a record, so
  the payload survives a deploy.
- **A client with no service links at all can no longer generate a report.** HubSpot, GA4,
  Yext, and SEMrush are mandatory for every client — `ReportGenerator::AdapterFailureError`
  raises the moment the first missing one is hit. This is a real behavior change from
  earlier versions of this feature, which degraded a fully-unconfigured client into an
  (almost) empty but successfully-generated report. Don't "fix" a failing generation for
  such a client by re-adding a degrade path — configure the missing service instead.
- **`ghl_data_status` only has two values now** (`connected` / `not_connected`) —
  `access_unavailable` (linked but the call failed) was removed along with the degrade
  path that used to set it. A linked GHL client's failure raises before that column is ever
  written.

### Not built yet

- **No send schedule.** Generation now runs automatically every 1st of the month via
  `EnqueueMonthlyReportsJob`, but nothing emails the result — the send date was left
  undecided in the SOW.
- **No alerting.** Nothing surfaces a failed or missing report to a human. The natural home
  is the stubbed Dashboard page.
- **No emailing.** See [monthly-report](monthly-report.md).

---

## Changing this feature

- **Reports cover completed months only.** The guard is not a convenience check.
- **Generation must stay idempotent.** Every retry path — job retry, manual re-run —
  depends on it.
- **HubSpot, Google Analytics, Yext, and SEMrush are mandatory for every client — a failure
  there must fail the whole run, not degrade.** This was a deliberate reversal of an earlier
  "degrade everything" design; don't revert individual services back to warn-and-continue
  without a matching product decision.
- **GHL and AI SEO stay opt-in — but only while genuinely unconfigured.** Not linked / not
  enrolled must keep degrading to an omitted section. The moment a client *is* linked or
  enrolled, that source joins the mandatory four; don't let it quietly degrade once opted
  in.
- **An unexpected exception must never be swallowed.** Log the attempt, then re-raise.
- **Never retroactively rewrite a generated report** from current state.
