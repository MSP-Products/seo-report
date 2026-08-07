---
title: Jobs and schedules
slug: jobs-and-schedules
kind: reference
last_verified: 2026-08-07
---

# Jobs and schedules

Everything that runs in the background, when, and what happens when it doesn't.

---

## What runs on a schedule

`config/recurring.yml`, under the `production` key only:

| Task | Schedule | What it does |
|---|---|---|
| `clear_solid_queue_finished_jobs` | Every hour at minute 12 | Solid Queue housekeeping |
| `scan_client_sitemaps` | Every day at 3am | `Client.kept.active.find_each { ScanClientSitemapJob.perform_later(_1.id) }` |
| `enqueue_hubspot_sync` | Every hour at minute 45 | `EnqueueHubspotSyncJob` |
| `test_client_service_connections` | Every day at 5am | `TestClientServiceConnectionsJob` |
| `refresh_ghl_token` | Every 4 hours | `RefreshGhlTokenJob` |
| `enqueue_monthly_reports` | The 1st of every month at 4am | `EnqueueMonthlyReportsJob` |

**Report generation is now scheduled; sending it is not.** `EnqueueMonthlyReportsJob` fans
out one `GenerateMonthlyReportJob` per active client for the last completed month, every
1st of the month. The scope of work left the send date undecided, and that decision is
still open — nothing emails the result yet. See
[report-generation](../features/report-generation.md).

---

## The jobs

### `ScanClientSitemapJob`

Wraps `SitemapScanner` for one practice.

- `queue_as :default`
- `discard_on ActiveRecord::RecordNotFound`
- **No `retry_on`, deliberately** — `SitemapScanner` never raises (a broken site marks that
  practice's scan failed and returns), and the next night's run is the natural retry.

### `GenerateMonthlyReportJob`

Wraps `ReportGenerator` for one practice and month.

- `queue_as :default`
- `retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3`
- `discard_on ActiveRecord::RecordNotFound`
- **Takes `(client_id, year, month)`** — IDs, never a record, so the payload survives a
  deploy mid-queue.
- Safe to retry because `ReportGenerator` is idempotent: re-running replaces that month's
  data rather than duplicating it.

Enqueued automatically by `EnqueueMonthlyReportsJob`, or manually for one client at a time
(see "Running things by hand" below).

### `SyncHubspotClientJob`

Wraps `SyncClientFromHubspot` for one client — pulls their HubSpot Company record and
writes name/address/website/onboarding status/AI SEO enrolment onto `Client`.

- `queue_as :default`
- `retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3`
- `discard_on ActiveRecord::RecordNotFound`
- Idempotent — a retry just re-fetches and overwrites the same fields.

### `EnqueueHubspotSyncJob`

The fan-out: one `SyncHubspotClientJob` per client with a HubSpot `ClientServiceLink`.

- `queue_as :default`
- **Scope is every client with a HubSpot link — kept or discarded, any onboarding_status.**
  Kept-and-pending is what catches a client whose HubSpot `active` flag just turned on,
  before `EnqueueMonthlyReportsJob`'s `Client.kept.active` targeting runs (see
  [integration-hubspot](../features/integration-hubspot.md) for why the ordering matters).
  **Discarded is included too**, deliberately: HubSpot is the source of truth for this
  client's real status regardless of discard state, so a client offboarded because its
  HubSpot company was deleted (`SyncClientFromHubspot#reset_to_pending`) needs this same
  scheduled re-check to ever get a chance at correcting back to `pending` — otherwise
  nothing but an admin manually re-saving that client's Edit page ever would.
- **Runs hourly.** Its original purpose (staleness ahead of the monthly enqueue) only ever
  needed a daily run — the 1st-of-the-month targeting decision doesn't get any more correct
  from checking more often than once between report cycles. It runs hourly because it's also
  the general mechanism keeping practice name/address/website/AI SEO enrollment in sync with
  HubSpot everywhere in the app (Dashboard, Report Log, eventually the Clients page), not
  only ahead of generation.

### `TestClientServiceConnectionsJob`

Wraps `LinkedServiceConnectionTester` — a single run, not a fan-out. Tests every already-linked
GHL, Yext, SEMrush, and GA4 `ClientServiceLink` (any link with an `external_id`) across every
kept client with one lightweight API call each, and writes the outcome onto that link's
`last_synced_at`/`last_sync_error` — the same columns the Sources tab's status label reads.

- `queue_as :default`
- No `retry_on`/`discard_on` — each link's check is independent and already isolated inside
  the loop; a single client or service erroring can't take down the run, and the next day's
  tick is the natural retry for anything that failed.
- **HubSpot is deliberately excluded.** `SyncClientFromHubspot` (run hourly via
  `EnqueueHubspotSyncJob`/`SyncHubspotClientJob`) already tests that connection as a side
  effect of keeping `onboarding_status` current, so testing it again here would just be a
  second call against the same endpoint for no new information.
- **One job for every client, not a fan-out**, unlike `EnqueueHubspotSyncJob`/
  `EnqueueMonthlyReportsJob` — each check is a single cheap read (an existence lookup, not a
  report-data pull), so one run comfortably covers the whole client list within the job's
  normal timeout.
- Each adapter's `check_connection` reuses its lightest already-implemented endpoint rather
  than a new one (e.g. GHL lists calendars instead of pulling a month of events; Yext looks up
  the entity directly instead of running an analytics report). `Adapters::Base#call(action:)`
  routes to either `#perform` (the full data pull) or `#check_connection` through the same
  credential check and error handling.
- **Runs daily, deliberately less often than HubSpot's hourly sync.** These four services
  don't drive `onboarding_status` or anything else time-sensitive the way HubSpot does — a
  connection-health check is inherently lower urgency, so daily is enough to surface a broken
  link well before the next report run needs it.

### `TestClientServiceConnectionJob`

The per-link counterpart to the job above — wraps
`LinkedServiceConnectionTester.test_link` for **one** `ClientServiceLink`. Enqueued by
`Client#sync_linked_services` (an `after_commit`) immediately after any client save, for every
linked GHL/Yext/SEMrush/GA4 service with a present `external_id` — the same
immediate-verification pattern `SyncHubspotClientJob` already has for HubSpot, minus
HubSpot's extra state-syncing side effects. Not gated on whether that specific link's
`external_id` changed: one form submission can touch several links at once
(`accepts_nested_attributes_for`), and a stale result on an untouched link is still worth
refreshing on the same save.

- `queue_as :default`
- `discard_on ActiveRecord::RecordNotFound`
- Takes a `client_service_link_id`, not a client ID — the link, not the client, is what's
  being tested.

### `RefreshGhlTokenJob`

Keeps the agency-wide GoHighLevel OAuth grant from ever sitting near expiry between monthly
report runs — see [integration-ghl](../features/integration-ghl.md#token-lifecycle).

- `queue_as :default`
- `retry_on Faraday::TimeoutError, Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 3`
- **No `discard_on`** — an unhandled `Faraday::Error` (e.g. an invalid-grant response) is
  left to fail the job outright, since that's a real anomaly worth surfacing rather than
  silently discarding.
- Delegates to `GhlOauthClient#refresh_if_stale!`, which is a no-op — not an error — when
  GHL has never been connected at all.
- **Runs every 4 hours**, deliberately narrower than the ~24h agency access token lifetime:
  `GhlOauthClient::EXPIRY_BUFFER` (12 hours) is wider than this job's cadence specifically
  so the job always catches a token before it actually expires. The wide buffer also means a
  real refresh (and the `last_verified_at` bump that comes with it) happens roughly every 12
  hours rather than only once near actual expiry.

### `EnqueueMonthlyReportsJob`

The fan-out: one `GenerateMonthlyReportJob` per active client, for the last completed month.

- `queue_as :default`
- No `retry_on`/`discard_on` of its own — each client's `GenerateMonthlyReportJob` carries
  its own retry policy, so a single client failing doesn't affect the fan-out itself.
- **Scope is `Client.kept.active`** — a `pending` client (not yet onboarded) or an
  `offboarded` one is skipped, same as a discarded (soft-deleted) one.
- **Creates each client's `MonthlyReport` row up front, `generation_status: "queued"`**,
  via `Client#find_or_create_monthly_report` — before `GenerateMonthlyReportJob` ever runs.
  This is what lets a dashboard show "34 of 42" the moment the run starts, not just once
  jobs begin executing.
- **Skips a client whose report for that month is already `ready`**, so re-running the
  fan-out (e.g. a retried scheduler tick) never duplicates work or re-pulls external APIs
  for a client that's already done. A `failed` report is **not** skipped — it's re-enqueued.
- **No guard against a client onboarded partway through the target month** — it will still
  get a full month's report. Accepted as a known gap for now.

---

## Conventions for adding a job

- **A job is a wrapper, never a home for logic.** `perform` resolves IDs to records and
  calls one service.
- **IDs in, not objects.**
- **Every job must be idempotent**, because every job can be retried.
- **Declare the failure policy explicitly** — `retry_on` for transient faults, `discard_on`
  for permanent ones. A job with neither retries forever on a bug.
- **Scheduled work goes in `config/recurring.yml`** under `production`.

---

## Operational reality

Three things to know before relying on any of this:

1. **The worker may not be running.** `config/puma.rb` starts Solid Queue inside Puma only
   if `SOLID_QUEUE_IN_PUMA` is set, and the Dockerfile's `CMD` runs only the web server. If
   that variable is unset in the deploy environment, **every enqueued job sits in the queue
   forever with no error** — including the nightly scan, the HubSpot sync, and the monthly
   generation fan-out. Verify it, or run `bin/jobs` as a separate process.
2. **Nothing alerts on failure.** There is no error-tracking service. A failed scan is
   recorded on the practice (`last_page_scan_status`); a failed generation is recorded in
   `report_generation_logs`. **Neither is pushed to a person** — the Dashboard shows both,
   but only if someone looks.
3. **Nothing detects work that never ran.** A missing report and a scan that stopped firing
   both look exactly like silence.

---

## Running things by hand

```bash
bin/jobs                                        # start a Solid Queue worker

# generate one report (prints the link, status and warnings)
REPORT_MONTH="2026-07" bin/rails reports:generate_real["Woodside Dental Care"]
```

```ruby
# enqueue a report instead of running it inline
GenerateMonthlyReportJob.perform_later(client.id, 2026, 7)

# run the monthly fan-out now instead of waiting for the 1st
EnqueueMonthlyReportsJob.perform_later

# sync one client from HubSpot now instead of waiting for the daily job
SyncHubspotClientJob.perform_later(client.id)

# run the HubSpot sync fan-out now instead of waiting for the next hourly tick
EnqueueHubspotSyncJob.perform_later

# test one link's connection now instead of waiting for the next daily tick
TestClientServiceConnectionJob.perform_later(client_service_link.id)

# test every linked GHL/Yext/SEMrush/GA4 connection now, as the daily schedule does
TestClientServiceConnectionsJob.perform_later

# refresh the GHL agency token now instead of waiting for the next 4-hour tick
RefreshGhlTokenJob.perform_later

# rescan one practice's website now
ScanClientSitemapJob.perform_later(client.id)

# rescan everything, as the nightly schedule does
Client.kept.active.find_each { |c| ScanClientSitemapJob.perform_later(c.id) }
```

See [MSP-GUIDE](../MSP-GUIDE.md) for the task-oriented versions of these.
