---
title: Jobs and schedules
slug: jobs-and-schedules
kind: reference
last_verified: 2026-08-02
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

**Report generation is not scheduled.** Nothing produces a monthly report automatically —
it is a command someone runs. The scope of work left the send date undecided, and that
decision is still open. See [report-generation](../features/report-generation.md).

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

**Not wired into `recurring.yml`.** It is enqueued manually today.

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
   forever with no error** — including the nightly scan. Verify it, or run `bin/jobs` as a
   separate process.
2. **Nothing alerts on failure.** There is no error-tracking service. A failed scan is
   recorded on the practice (`last_page_scan_status`); a failed generation is recorded in
   `report_generation_logs`. **Neither is surfaced anywhere a human looks.**
3. **Nothing detects work that never ran.** A missing report and a scan that stopped firing
   both look exactly like silence.

The stubbed Dashboard page is the natural home for all three.

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

# rescan one practice's website now
ScanClientSitemapJob.perform_later(client.id)

# rescan everything, as the nightly schedule does
Client.kept.active.find_each { |c| ScanClientSitemapJob.perform_later(c.id) }
```

See [MSP-GUIDE](../MSP-GUIDE.md) for the task-oriented versions of these.
