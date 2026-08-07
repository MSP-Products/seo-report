---
title: HubSpot integration
slug: integration-hubspot
status: shipped
last_verified: 2026-08-07
related: [integrations, report-generation]
---

# HubSpot integration

> **Status:** shipped — verified against a real MSP HubSpot portal. Onboarding status,
> onboarding date, and AI SEO enrollment are all live · **Last verified:** 2026-08-07
>
> HubSpot is the source of truth for a practice's own details, whether they are enrolled in
> AI SEO, and which month is their first report.

---

## For everyone

### Purpose

MSP already tracks each practice as a company record in HubSpot. Rather than maintain a
second copy of a practice's name, address and enrolment status here, the system reads them
from HubSpot on every report run — and, separately, once an hour, independent of generation
(see [jobs-and-schedules](../reference/jobs-and-schedules.md)).

**This means HubSpot wins.** Editing a practice's name or AI SEO enrolment in our database
has no lasting effect — the next sync overwrites it from HubSpot. Change it in HubSpot.

### What it provides

| Field | Effect |
|---|---|
| Name, address, website | Shown in the report header; the website also drives the page scan and keyword matching |
| **Onboarding status** | Whether the practice is `active` or `offboarded` — gates whether it gets a report generated at all |
| **Onboarding date** | Which month is a practice's "first report" (baseline) vs. an ongoing one |
| **AI SEO enrolment** | **Decides whether the AI search section appears in their report** |

The last two matter most: both are read fresh on every generation run and captured into
that month's report — enrolling a practice in AI SEO makes the AI section appear from the
next report onward, and the onboarding date decides once, permanently, which single report
gets the baseline treatment.

### Setting it up

- **Credential:** a private-app access token, agency-wide, entered under Connections.
- **Per practice:** the HubSpot **Company record ID**.

### When data is missing

| Situation | Effect |
|---|---|
| No company ID recorded | The call is skipped; the practice's stored details are used as-is |
| The call fails | Warning recorded; stored details used as-is; **the rest of the report is unaffected** |
| A property is empty in HubSpot | Name/address/website are left unchanged rather than blanked. **`active`** missing reads as `false` (offboarded). **Onboarding date** missing falls back to "no earlier report exists" for deciding the first report |

A HubSpot outage never blocks a report. It only means the practice's details are not
refreshed that run.

### FAQ

**Q: We changed a practice's name here and it reverted.**
A: Expected. HubSpot is the source of truth. Change it there.

**Q: We enrolled a practice in AI SEO but their report has no AI section.**
A: Enrolment is captured per report at generation time, so it appears from the *next*
report onward and never rewrites past ones. Check the practice's Services property in
HubSpot actually includes the "AI SEO" tag.

**Q: A practice is marked inactive in HubSpot but isn't actually offboarded, just new.**
A: HubSpot's `active` property has no in-between state — it's a plain yes/no. There's no
way to distinguish "not yet onboarded" from "offboarded" from this field alone; see Gotchas.

**Q: A practice's report for a much later month is showing the baseline "first report"
intro instead of the usual monthly one, or vice versa.**
A: Check their GMB SEO Start Date property in HubSpot — that's what decides which single
calendar month gets the baseline treatment (see Field mapping, below).

---

## For developers

### API reference

**Base URL** `https://api.hubapi.com`
**Auth** `Authorization: Bearer <private-app token>`

#### Company — `GET /crm/v3/objects/companies/{company_id}`

| Parameter | Value |
|---|---|
| `properties` | `name,address,website,active,gmb_seo_start_date,service_purchased` |

**Response shape:** `{ "properties": { "name": "...", ... } }`

This adapter ignores `report_month` entirely — it reads current state, not a monthly
window.

### Field mapping

→ the `Client` record itself, **not** a `Report*` table. This is the only adapter that
writes to `Client`.

None of these three status fields have an obviously-named property in MSP's portal — all
three were confirmed against a real company record before being wired in, not guessed from
naming convention:

| HubSpot property | Client column | Transform |
|---|---|---|
| `name` | `name` | |
| `address` | `address` | |
| `website` | `website_url` | |
| `active` | `onboarding_status` | `"true"` → `"active"`, anything else (including missing) → `"offboarded"` — there is no "pending" equivalent in HubSpot |
| `gmb_seo_start_date` | `onboarded_at` | `Date.parse`, only when present. The "GMB" name predates this product but MSP confirmed it's still the field in current use for onboarding date |
| `service_purchased` | `ai_seo_enrolled` | Semicolon-delimited tag list; `true` when it includes the literal tag `"AI SEO"` |

`ReportGenerator#sync_hubspot` and the hourly sync job both go through
`SyncClientFromHubspot`, which applies these with `.slice(...).compact` — a nil property
(name/address/website/onboarded_at) leaves the existing value alone rather than blanking
it. `onboarding_status`/`ai_seo_enrolled` are never nil, so `.compact` never applies to
them.

`Client#find_or_create_monthly_report` is what actually consumes `onboarded_at`: it compares
the report's month against `onboarded_at.beginning_of_month` to decide `is_first_report`,
falling back to "no earlier report exists" only when `onboarded_at` isn't known yet — see
[report-generation](report-generation.md).

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/hubspot_adapter.rb` | Fetches and maps the Company properties |
| `app/services/sync_client_from_hubspot.rb` | Calls the adapter and writes the result onto `Client`; shared by generation and the hourly sync |
| `app/services/report_generator.rb` | `sync_hubspot` — delegates to `SyncClientFromHubspot` during generation |
| `app/jobs/enqueue_hubspot_sync_job.rb` | Hourly fan-out over every client with a HubSpot link, any status, kept or discarded |
| `app/jobs/sync_hubspot_client_job.rb` | Per-client wrapper around `SyncClientFromHubspot` |
| `app/models/client.rb` | `sync_linked_services`, `skip_service_sync`, `find_or_create_monthly_report` — where `onboarded_at` decides `is_first_report` |
| `test/services/adapters/hubspot_adapter_test.rb` | Property mapping, including the offboarded/no-AI-SEO/no-onboarding-date cases |
| `test/services/sync_client_from_hubspot_test.rb` | Writes on success, leaves the client untouched on an ordinary failure, normalizes to pending/offboarded when not connected |
| `test/jobs/enqueue_hubspot_sync_job_test.rb` | Targets every linked client including `pending` and discarded ones |
| `test/models/client_test.rb` | `is_first_report` from `onboarded_at`, including the backfill case that motivated sourcing it from HubSpot at all |

### Data

Writes `name`, `address`, `website_url`, `onboarding_status`, `onboarded_at`,
`ai_seo_enrolled` on `Client`.

Downstream consequences worth knowing:

- `website_url` drives the page scan's sitemap lookup **and** SEMrush's URL mask. A wrong
  value silently breaks both.
- `ai_seo_enrolled` is read at generation time to decide whether `ReportAiVisibility` is
  written at all.
- `onboarding_status` decides whether `EnqueueMonthlyReportsJob` even targets this client —
  see why the hourly sync job exists, below.
- `onboarded_at` decides `is_first_report` — see
  [report-generation](report-generation.md#gotchas).

### Why there's an hourly sync job, not just the one during generation

`EnqueueMonthlyReportsJob` reads `Client.kept.active` to decide who gets a report *before*
any generation (and its `sync_hubspot` step) has run for that cycle. Without a separate
sync, a client whose HubSpot `active` flag just turned `true` would still show their old,
stale `onboarding_status` locally at the exact moment targeting happens — and would only get
picked up the report *after* next.

`EnqueueHubspotSyncJob` closes that gap, and deliberately targets every client with a
HubSpot link regardless of status — kept or discarded, connected or not, not just
currently-active ones — since a `pending` client going active is one case it exists to
catch, and a **discarded** client whose HubSpot company was deleted or unlinked
(`SyncClientFromHubspot#sync_unverified_status`) is the other: without including discarded
clients, that normalization could only ever be triggered by an admin happening to re-save
the client's Edit form, since the immediate on-save check deliberately skips itself right
after a manual offboard/restore (`Client#skip_service_sync`, so the admin's own action isn't
invisibly undone in the same request). It runs **hourly**
rather than daily: the targeting gap itself only ever needed a run sometime before the
monthly 4am enqueue, but this job is also the general mechanism keeping practice details
(and, now, discard state) in sync with HubSpot everywhere in the app, not only ahead of
generation — so it runs often enough that "stale" never means more than an hour.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| Missing company ID | `Result.failure("hubspot: no company id configured…")` | `error_log` |
| HTTP error | `Result.failure` | `error_log` |
| `active` property missing or unset | **Silent** — reads as `false`, i.e. offboarded | **Nowhere** |
| `onboarding_status` outside the enum | Can't happen — the adapter only ever produces `"active"` or `"offboarded"`, both valid | — |

The third row is worth knowing: a client with no `active` value set in HubSpot at all reads
as offboarded by default, not as an error.

### Gotchas

- **This adapter writes to `Client`, not to a report table.** It is the one place practice
  details are updated, which is why local edits do not stick.
- **`.compact` means nil never blanks name/address/website/onboarded_at.**
  `onboarding_status` and `ai_seo_enrolled` are never nil, so this doesn't apply to them.
- **`onboarding_status` has no "pending" path through this adapter.** `active` is a plain
  boolean in HubSpot; a client only reaches this sync once they already have a real company
  record, so `false` is read as offboarded, not "not yet onboarded." If MSP ever needs a
  genuine pending-via-HubSpot state, this mapping needs revisiting.
- **`service_purchased` is a raw semicolon-delimited string**, not an array — HubSpot's API
  shape for multi-select checkbox properties. Split on `;` before checking tag membership.
- **None of `active`, `gmb_seo_start_date`, or `service_purchased` are named for what they
  mean here.** They were confirmed live against a real company record, not inferred from
  their labels — don't rename or "clean up" these property references without re-confirming
  against the portal first.
- **`report_month` is ignored** — unlike every other adapter, this one is not month-scoped.

### Not built yet

- No writing back to HubSpot; the flow is read-only.

---

## Changing this feature

- **HubSpot stays the source of truth** for practice details, onboarding status, onboarding
  date, and AI SEO enrolment. Do not add a competing local edit path without deciding which
  wins.
- **Keep `.compact`** for the name/address/website/onboarded_at fields so a missing property
  never blanks stored data.
- **Don't rename or reinterpret `active`, `gmb_seo_start_date`, or `service_purchased`**
  without re-confirming against a real company record — none of them are named for their
  purpose here.
- **If the "no pending state" gotcha ever becomes a real problem**, that's a mapping change
  here, not a workaround in `ReportGenerator` or the `Client` model.
