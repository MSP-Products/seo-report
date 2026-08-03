---
title: Report generation
slug: report-generation
status: partial
last_verified: 2026-08-03
related: [monthly-report, integrations, page-scan, admin-panel]
---

# Report generation

> **Status:** partial — generation is scheduled and safe to re-run, but nothing emails
> the result and nothing alerts on failure · **Last verified:** 2026-08-03
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
5. Each source that fails is noted as a warning, and the run keeps going.
6. Unless it is a first report, a short written summary is generated from the figures now
   stored.
7. The report is marked generated, and the attempt is recorded with its warnings.

**Re-running is always safe.** Generating again for the same practice and month replaces
that month's data rather than duplicating it. So the fix for a failed or partial run is
simply to fix the cause and run it again.

### When data is missing

This is where the report's degraded states are decided.

| What's missing | What happens |
|---|---|
| Any single external service fails | A warning is recorded, that section's data is left absent, and the rest of the report is produced normally |
| The practice has no link for a service | That service is skipped without being called |
| The practice has no appointment scheduler | Recorded as "not connected" without ever calling the scheduler service |
| The scheduler is linked but the call fails | Recorded as "access unavailable" — a different state, distinguishable afterwards |
| The summary-writing service is unavailable | The report is produced with no highlights banner |
| Something unexpected goes wrong | The attempt is recorded as **failed** and the error is raised. This means a bug, not a service being down |

The distinction in that last row is the design: **a third-party API being down is normal
and produces a degraded report. An unexpected error is a defect and is allowed to fail
loudly.**

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
2. **`find_or_create_report`** — `find_or_create_by!(report_month:)`, setting
   `is_first_report` when no earlier report exists for that client.
3. **`sync_hubspot`** — updates the `Client` record itself from HubSpot (name, address,
   website, onboarding status, AI SEO enrolment). HubSpot is the source of truth for these.
4. **`sync_traffic`** — GA4 for visits, then GHL for appointments/revenue **only if a GHL
   `ClientServiceLink` exists**; otherwise sets `ghl_data_status: "not_connected"` without
   an API call.
5. **`sync_yext`** — one Yext call fanning into three writes: citations, AI visibility, GBP
   activity.
6. **`sync_keywords`** — SEMrush rankings, carrying last month's `position` forward into
   this month's `previous_position`.
7. **`sync_pages_published`** — reads `SitemapPage` rows whose `first_seen_at` falls in the
   month. Does **not** trigger a scan; see [page-scan](page-scan.md).
8. **`sync_highlights`** — skipped for first reports; calls `HighlightGenerator`.
9. **`report.update!(generated_at:)`** then `log_attempt(status: "success")`.

Every adapter returns an `Adapters::Result` rather than raising, so a failure appends to
`warnings` and the run continues. The single top-level `rescue StandardError` logs the
attempt as `failed` and **re-raises** — it never swallows.

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
| `lib/tasks/real_client.rake` | `reports:generate_real` — how generation is actually invoked today |
| `test/services/report_generator_test.rb` | The reference test: happy path, idempotency, each degraded state |
| `test/jobs/enqueue_monthly_reports_job_test.rb` | Covers the active/pending/offboarded/already-generated fan-out rules |

### Data

| Model / table | What it holds here |
|---|---|
| `MonthlyReport` | Created or found; `generated_at` stamped at the end |
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
| One adapter returns a failure | That section degraded on the report | `report_generation_logs.error_log`, status still `success` |
| Anthropic unavailable or no API key | No highlights banner | Rails log warning; **not** in `error_log` |
| Unexpected exception | Nothing — the run aborts, report stays ungenerated | `report_generation_logs` status `failed`, plus the raised error |
| Nobody runs generation at all | No report exists for that month | **Nowhere** — nothing detects a missing report |

That last row is the biggest operational gap in the system.

### Gotchas

- **`sync_hubspot` writes to `Client`.** Editing a practice's name or AI SEO enrolment
  locally is pointless — the next run overwrites it from HubSpot.
- **AI visibility is frozen per report** deliberately. It is written only when
  `client.ai_seo_enrolled?` **at run time**, and afterwards the report renders based on the
  row existing — so an enrolment change never rewrites history.
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
- **An external API being down must never fail the run.** Degrade and warn.
- **An unexpected exception must never be swallowed.** Log the attempt, then re-raise.
- **Never retroactively rewrite a generated report** from current state.
