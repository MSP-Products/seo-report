---
title: HubSpot integration
slug: integration-hubspot
status: partial
last_verified: 2026-08-02
related: [integrations, report-generation]
---

# HubSpot integration

> **Status:** partial — **not yet verified against a live account**; the custom property
> names are a placeholder convention · **Last verified:** 2026-08-02
>
> HubSpot is the source of truth for a practice's own details and whether they are enrolled
> in AI SEO.

---

## For everyone

### Purpose

MSP already tracks each practice as a company record in HubSpot. Rather than maintain a
second copy of a practice's name, address and enrolment status here, the system reads them
from HubSpot on every report run.

**This means HubSpot wins.** Editing a practice's name or AI SEO enrolment in our database
has no lasting effect — the next report run overwrites it from HubSpot. Change it in
HubSpot.

### What it provides

| Field | Effect |
|---|---|
| Name, address, website | Shown in the report header; the website also drives the page scan and keyword matching |
| Onboarding status | Whether the practice is active |
| Onboarded date | When they joined |
| **AI SEO enrolment** | **Decides whether the AI search section appears in their report** |

That last one matters most: it is read fresh on every run and captured into that month's
report, so enrolling a practice in HubSpot makes the AI section appear from the next report
onward.

### Setting it up

- **Credential:** a private-app access token, agency-wide, entered under Connections.
- **Per practice:** the HubSpot **Company record ID**.

### When data is missing

| Situation | Effect |
|---|---|
| No company ID recorded | The call is skipped; the practice's stored details are used as-is |
| The call fails | Warning recorded; stored details used as-is; **the rest of the report is unaffected** |
| A property is empty in HubSpot | That field is left unchanged rather than blanked |

A HubSpot outage never blocks a report. It only means the practice's details are not
refreshed that month.

### Known limits

**The custom property names have not been confirmed against MSP's actual HubSpot setup.**
The adapter reads `onboarding_status`, `onboarded_at` and `ai_seo_enrolled` as Company
properties, but those names are a convention chosen while building, not something verified.
**Confirm them before going live**, or AI SEO enrolment will silently read as false for
every practice and no report will ever show the AI section.

### FAQ

**Q: We changed a practice's name here and it reverted.**
A: Expected. HubSpot is the source of truth. Change it there.

**Q: We enrolled a practice in AI SEO but their report has no AI section.**
A: Two possible causes. Enrolment is captured per report at generation time, so it appears
from the *next* report onward and never rewrites past ones. Or the HubSpot property name
does not match what the adapter reads — see the limit above.

---

## For developers

### API reference

**Base URL** `https://api.hubapi.com`
**Auth** `Authorization: Bearer <private-app token>`

#### Company — `GET /crm/v3/objects/companies/{company_id}`

| Parameter | Value |
|---|---|
| `properties` | `name,address,website,onboarding_status,onboarded_at,ai_seo_enrolled` |

**Response shape:** `{ "properties": { "name": "...", ... } }`

This adapter ignores `report_month` entirely — it reads current state, not a monthly
window.

### Field mapping

→ the `Client` record itself, **not** a `Report*` table. This is the only adapter that
writes to `Client`.

| HubSpot property | Client column | Transform |
|---|---|---|
| `name` | `name` | |
| `address` | `address` | |
| `website` | `website_url` | |
| `onboarding_status` | `onboarding_status` | Must match the enum: `pending` / `active` / `offboarded` |
| `onboarded_at` | `onboarded_at` | `Date.parse`, only when present |
| `ai_seo_enrolled` | `ai_seo_enrolled` | Cast via `ActiveModel::Type::Boolean` — HubSpot returns `"true"` / `"false"` strings |

`ReportGenerator#sync_hubspot` applies these with `.slice(...).compact`, so **a nil property
leaves the existing value alone** rather than blanking it.

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/hubspot_adapter.rb` | The whole integration |
| `app/services/report_generator.rb` | `sync_hubspot` — the only place `Client` is written by generation |
| `app/models/client.rb` | The enums these values must satisfy |
| `test/services/adapters/hubspot_adapter_test.rb` | Property mapping and the boolean cast |

### Data

Writes `name`, `address`, `website_url`, `onboarding_status`, `onboarded_at`,
`ai_seo_enrolled` on `Client`.

Downstream consequences worth knowing:

- `website_url` drives the page scan's sitemap lookup **and** SEMrush's URL mask. A wrong
  value silently breaks both.
- `ai_seo_enrolled` is read at generation time to decide whether `ReportAiVisibility` is
  written at all.
- `onboarding_status` must satisfy the enum, which `validate: true` enforces — an
  unexpected HubSpot value raises.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| Missing company ID | `Result.failure("hubspot: no company id configured…")` | `error_log` |
| HTTP error | `Result.failure` | `error_log` |
| Property name mismatch | **Silent** — reads as nil, field left unchanged, AI SEO reads false | **Nowhere** |
| `onboarding_status` outside the enum | `ArgumentError` on save — **fails the whole run** | `status: "failed"` |

The third row is the dangerous one: a wrong property name produces no error anywhere, just
a practice that never shows an AI section.

### Gotchas

- **This adapter writes to `Client`, not to a report table.** It is the one place practice
  details are updated, which is why local edits do not stick.
- **`.compact` means nil never blanks a field.** An emptied HubSpot property leaves the old
  value in place rather than clearing it.
- **`ai_seo_enrolled` arrives as a string.** HubSpot returns `"true"` / `"false"`, hence the
  explicit boolean cast — a truthiness check would treat `"false"` as true.
- **`onboarding_status` is enum-validated**, so an unexpected HubSpot value is a hard
  failure rather than a degraded section. That is deliberate but sharp-edged.
- **`report_month` is ignored** — unlike every other adapter, this one is not
  month-scoped.

### Not built yet

- **Live verification.** No call has been made against a real MSP HubSpot account.
- **Property name confirmation** — the highest-priority open item on this integration.
- No writing back to HubSpot; the flow is read-only.

---

## Changing this feature

- **HubSpot stays the source of truth** for practice details and AI SEO enrolment. Do not
  add a competing local edit path without deciding which wins.
- **Keep `.compact`** so a missing property never blanks stored data.
- **Keep the explicit boolean cast** on `ai_seo_enrolled`.
- **Confirm the custom property names before go-live** and update this document when you
  do.
