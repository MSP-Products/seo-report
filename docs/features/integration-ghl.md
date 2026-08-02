---
title: GoHighLevel integration
slug: integration-ghl
status: partial
last_verified: 2026-08-02
related: [integrations, monthly-report, report-generation]
---

# GoHighLevel integration

> **Status:** partial — **not yet verified against a live account**; agency-wide OAuth is
> blocked on Marketplace access · **Last verified:** 2026-08-02
>
> GoHighLevel supplies appointments booked and estimated revenue — the two figures that
> show a practice the money side of their SEO.

---

## For everyone

### Purpose

MSP offers practices an appointment scheduler built on GoHighLevel. For practices using it,
the report can show how many appointments were booked that month and the revenue attributed
to them — the closest thing in the report to a return-on-investment figure.

### What it provides

| Report figure | Source |
|---|---|
| Appointments booked | Count of calendar events in the month |
| Estimated revenue generated | Sum of won opportunities in the month |

The revenue figure gets the report's only "hero" treatment — a dark filled tile — because
it is the number practices care about most.

### Setting it up

- **Credential:** an access token, agency-wide, entered under Connections.
- **Per practice:** the GHL **location ID**.

### The enrolment signal

**This integration is unique: whether a practice is linked to GHL *is* the record of
whether they use our scheduler.** There is no separate "has scheduler" flag anywhere.

- **Linked** → the API is called, real figures appear.
- **Not linked** → the API is **never called**, and both figures show **?** with a note
  explaining that connecting the scheduler will populate them.

So linking a practice to GHL is not just configuration — it changes what their report
claims about them.

### When data is missing

| Situation | What the client sees | Stored as |
|---|---|---|
| No GHL link at all | **?** for both figures, plus the explanatory note | `not_connected` |
| Linked but the call failed | The same **?** and note | `access_unavailable` |
| Linked and working | Real figures, revenue in the hero tile | `connected` |

The first two look identical to the practice but are stored as different states, so
afterwards you can tell "they don't use the scheduler" from "we couldn't reach GHL".

### Known limits

- **"Estimated revenue" means won opportunities updated in the month**, not revenue
  actually collected, and not revenue attributable to SEO specifically.
- **"Appointments booked" counts calendar events in the month**, which includes any event
  on that location's calendars, not only new patient bookings.

Both are proxies. They are labelled "estimated" in the report for that reason.

### FAQ

**Q: A practice uses our scheduler but their report shows question marks.**
A: Their GHL location link is missing. Presence of the link is the enrolment signal, so
without it the system never even calls GHL.

**Q: The revenue figure doesn't match what the practice thinks they earned.**
A: It is the sum of opportunities marked won in GHL during that month. It is an estimate
derived from the pipeline, not accounting data.

**Q: Can we show appointments without revenue?**
A: Not currently — both come from the same integration and appear or disappear together.

---

## For developers

### API reference

**Base URL** `https://services.leadconnectorhq.com` (GHL v2)
**Auth** `Authorization: Bearer <token>` **and** `Version: 2021-07-28`

The `Version` header is mandatory on v2 — omitting it fails the request.

#### Appointments — `GET /calendars/events`

| Parameter | Value |
|---|---|
| `locationId` | the location ID |
| `startTime` | month start, **epoch milliseconds** |
| `endTime` | month end, **epoch milliseconds** |

Reads `events` and takes its **size**. The count is the metric; no event detail is stored.

#### Revenue — `GET /opportunities/search`

| Parameter | Value |
|---|---|
| `location_id` | the location ID |
| `status` | `won` |
| `date_updated_start` | month start, **ISO 8601 date** |
| `date_updated_end` | month end, ISO 8601 date |

Reads `opportunities` and sums `monetaryValue`.

**Note the inconsistency between these two endpoints** — it is GHL's, not ours, and it is
easy to get wrong when adding a third call:

| | Appointments | Revenue |
|---|---|---|
| Location parameter | `locationId` (camelCase) | `location_id` (snake_case) |
| Date format | epoch milliseconds | ISO 8601 |

### Field mapping

→ `ReportTraffic`

| Source | Column |
|---|---|
| `events.size` | `appointments_booked` |
| `sum(opportunities[].monetaryValue)` | `estimated_revenue` |
| *constant* `"connected"` | `ghl_data_status` |

`ghl_data_status` is set to `not_connected` or `access_unavailable` by `ReportGenerator`,
not by this adapter — the adapter only ever reports success.

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/ghl_adapter.rb` | Both calls |
| `app/services/report_generator.rb` | `sync_traffic` — decides `not_connected` vs `access_unavailable` before or after calling |
| `app/models/report_traffic.rb` | The three-value `ghl_data_status` enum |
| `app/presenters/report_presenter.rb` | `ghl_connected?` — drives the `?` placeholder |
| `app/views/reports/_traffic.html.erb` | The `?` placeholders and explanatory callout |
| `test/services/adapters/ghl_adapter_test.rb` | Both calls, and the missing-location-id case |

### Data

Writes `appointments_booked`, `estimated_revenue` (decimal, precision 12 scale 2) and
`ghl_data_status` on `ReportTraffic`.

**The link's existence is the enrolment record.** `ReportGenerator` checks
`client.client_service_links.exists?(service: "ghl")` before constructing the adapter at
all.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| No `ClientServiceLink` for `ghl` | Adapter **never constructed**; `ghl_data_status: "not_connected"` | Nothing — a normal state |
| Link exists, `external_id` blank | `Result.failure("ghl: no location id configured…")` | `error_log`, status `access_unavailable` |
| HTTP error after retries | `Result.failure` | `error_log`, status `access_unavailable` |
| Missing `Version` header | Request rejected by GHL | `error_log` |

### Gotchas

- **Absence of a link is meaningful, not merely missing config.** Linking a practice
  changes what their report asserts about them, so do not link one "to see if it works".
- **The two endpoints disagree on parameter style and date format.** Copying one call's
  shape to write a third will fail.
- **`Version: 2021-07-28` is required** on every v2 request.
- **Epoch values are milliseconds**, hence the `* 1000`.
- **The adapter never returns a non-`connected` status** — that distinction is
  `ReportGenerator`'s, which is why `sync_traffic` has branching that looks redundant but
  is not.
- **`monetaryValue` is coerced with `to_f`**, so a missing or non-numeric value contributes
  zero rather than raising.

### Not built yet

- **Live verification.** No call has been made against a real GHL account.
- **Agency-wide OAuth.** GHL Private Integration Tokens do not scale past one client, so a
  proper Marketplace OAuth app is needed for a single agency credential to cover every
  practice. Marketplace access is the blocker — until then, per-practice credential
  overrides are the only workable route.
- No appointment or opportunity detail is stored, only the aggregates.

---

## Changing this feature

- **Keep link-presence as the enrolment signal**, or introduce an explicit flag and migrate
  deliberately — but do not have both.
- **Keep `not_connected` and `access_unavailable` distinct.** They look identical to the
  client but must stay distinguishable to MSP.
- **Never call GHL for an unlinked practice.** The check exists so an unenrolled practice
  costs nothing and generates no misleading warning.
