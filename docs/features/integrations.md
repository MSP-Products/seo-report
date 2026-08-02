---
title: External integrations
slug: integrations
status: partial
last_verified: 2026-08-02
related: [report-generation, monthly-report, admin-panel]
---

# External integrations

> **Status:** partial — Yext, SEMrush and GA4 verified against live APIs; HubSpot and GHL
> not yet · **Last verified:** 2026-08-02
>
> The five outside services the report is built from, what each one provides, and what
> happens when one is unavailable.

---

## For everyone

### Purpose

MSP does not hold this data itself. Every figure in a report comes from a service that
already tracks part of a practice's online presence. This is the layer that fetches it.

| Service | Provides |
|---|---|
| **HubSpot** | The practice's own details, and whether they are enrolled in AI SEO |
| **Google Analytics** | Website visits, visitors, pages per visit, and where traffic came from |
| **GoHighLevel** | Appointments booked and estimated revenue |
| **Yext** | Directory listings performance, AI visibility, and Google Business Profile activity |
| **SEMrush** | Where the practice's tracked keywords rank |

### Who uses it

Nobody directly. MSP staff maintain the credentials
([MSP-GUIDE](../MSP-GUIDE.md#add-or-update-an-api-credential)) and the per-practice IDs;
the fetching happens during report generation.

### How it behaves

Two kinds of credential:

- **Agency-wide** — one key MSP holds that works for every practice, set in the admin
  panel under Connections.
- **Per-practice ID** — each service identifies a practice by its own identifier, which
  must be recorded per practice. See
  [where each ID comes from](../MSP-GUIDE.md#where-each-id-comes-from).

A practice can also carry its own credential override for a service, though in normal
operation the agency-wide one is used.

**Every service is optional.** A practice with no link to a service simply has that part
of their report unavailable — nothing errors, nothing blocks.

### When data is missing

**No external service can break a report.** Each failure is contained to its own section.

| Situation | Effect |
|---|---|
| No credential configured | That service is skipped; its sections show placeholders |
| No per-practice ID recorded | Same — the service is not called |
| Service returns an error or times out | Warning recorded, that section left empty, rest of the report produced |
| The service is slow or briefly unreachable | Automatically retried four times with increasing gaps before giving up |
| GoHighLevel not linked | Treated as "practice has no scheduler" — appointments and revenue show **?** |

### Known limitations by service

Honest limits discovered while verifying against real accounts, rather than assumed from
documentation:

**Yext**

- No separate figures for "driving directions" and "website clicks" — only a combined
  engagement total. The report omits that breakdown.
- No breakdown of where AI citations came from, so those figures stay empty.
- Sentiment arrives as three-way negative/neutral, with positive derived as the remainder.
- The Google Business Profile part uses an endpoint that has **not** been verified against
  a real response. Treat GBP figures as lower confidence than citations and AI visibility.

**SEMrush**

- Provides current rankings only. Month-over-month movement is MSP's own record, carried
  forward from the previous report.
- "Potential traffic" is an approximation — SEMrush exposes no dedicated figure for it on
  this report.

**Google Analytics**

- Channels outside Organic, Direct, Referral and Paid still count toward total visits but
  are not broken out individually.

**HubSpot and GoHighLevel**

- Neither has been verified against a live account yet. HubSpot's custom property names in
  particular are a placeholder convention and must be confirmed before going live.

### FAQ

**Q: Do we need a separate account per practice?**
A: No. One agency credential per service covers every practice. Only the per-practice ID
differs — except Google Analytics, which also needs the practice to grant our service
account access to their property.

**Q: A practice's data looks wrong. Is it us or the service?**
A: Generation records a warning per service. If a section is empty, check those warnings
first — an empty section almost always means a credential or ID problem, not genuine
inactivity.

**Q: What happens if a service changes its API?**
A: That service's sections degrade to placeholders and warnings are recorded. The rest of
the report is unaffected.

---

## For developers

### How it works

Every adapter subclasses `Adapters::Base`, declares `SERVICE`, and implements `#perform`.
`Base` owns:

- **Credential resolution** — `ClientServiceLink#override_credentials` (per practice) wins
  over `AgencyConnection#encrypted_credentials` (agency-wide). Both are
  ActiveRecord-encrypted JSON blobs.
- **The `#call` contract** — returns `Result.failure` when no credentials are configured,
  otherwise delegates to `#perform` and converts any `Faraday::Error` into
  `Result.failure`.
- **`external_id`** — the practice's identifier in that service, from `ClientServiceLink`.
- **`month_range`** — via the shared `MonthlyRange` concern.

**Adapters return, never raise.** `Adapters::Result` is a `Data.define(:success?, :data,
:error)` with `.success` / `.failure` constructors. This is what lets one dead API degrade
one section instead of failing the run.

HTTP setup is shared through `Adapters::ConnectionBuilder` — 10s open / 15s read timeouts
and four retries spaced 2s/4s/8s/16s. The wide spacing is deliberate: `Net::HTTP` commits
to one resolved address per attempt and will not fall back to another from a DNS
round-robin pool, so a retry needs real spacing to have a chance at a fresh DNS answer.

| Adapter | Auth | Notes |
|---|---|---|
| `HubspotAdapter` | Bearer private-app token | Reads Company properties; **property names are a placeholder** |
| `GhlAdapter` | Bearer OAuth token + pinned `Version` header | Counts calendar events; sums won opportunities |
| `YextAdapter` | `api_key` query param + `v` version | POSTs to the Analytics Reports API; three concerns in one adapter |
| `SemrushAdapter` | `key` query param | Position Tracking report; JSON, not the classic CSV |
| `GoogleAnalyticsAdapter` | **Service-account JWT Bearer (RFC 7523)** | Mints its own token; two `runReport` calls |

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/base.rb` | Credential resolution, the `#call` contract, `#perform` template method |
| `app/services/adapters/result.rb` | The success/failure value object every adapter returns |
| `app/services/adapters/connection_builder.rb` | Shared Faraday timeouts and retry policy |
| `app/services/adapters/hubspot_adapter.rb` | Practice details, AI SEO enrolment |
| `app/services/adapters/ghl_adapter.rb` | Appointments, revenue |
| `app/services/adapters/yext_adapter.rb` | Citations, AI visibility, GBP activity |
| `app/services/adapters/semrush_adapter.rb` | Keyword rankings |
| `app/services/adapters/google_analytics_adapter.rb` | Traffic; also does its own JWT signing |
| `app/models/agency_connection.rb` | Agency-wide credentials, field definitions, display metadata |
| `app/models/client_service_link.rb` | Per-practice `external_id` and credential override |
| `app/models/service.rb` | The valid service keys, backing FK constraints |
| `app/services/concerns/monthly_range.rb` | Shared month-as-Range helper |
| `test/services/adapters/` | One test per adapter, all HTTP stubbed with WebMock |

### Data

| Model / table | What it holds here |
|---|---|
| `Service` | Lookup table of valid keys; primary key is the key string itself |
| `AgencyConnection` | One row per service; `encrypted_credentials` JSON blob, `credential_status` |
| `ClientServiceLink` | One row per practice per service; `external_id`, optional `override_credentials` |

Invariants:

- `agency_connections.service` and `client_service_links.service` are **foreign keys to
  `services`**, replacing a hardcoded list previously duplicated across two enums.
- `client_service_links` is unique on `(client_id, service)`.
- Both credential columns use `encrypts`. **Never add a plaintext secret column.**
- `Service::KEYS` exists for code that needs the list when the DB was schema-loaded rather
  than migrated.

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| No credentials configured | Section placeholder | `report_generation_logs.error_log` |
| Missing `external_id` | Section placeholder | Same, with a specific "no ... configured" message |
| HTTP error or timeout after retries | Section placeholder | Same |
| Malformed response (e.g. non-JSON body) | **Generation fails** | `status: "failed"` — a `JSON::ParserError` is not a `Faraday::Error`, so it is treated as a bug |
| Credential expired | Section placeholder | Same as an HTTP error; `credential_status` is **not** updated |

### Gotchas

- **SEMrush needs the full `project_id_campaign_id` pair** from the Position Tracking URL,
  not the shorter project ID. The wrong one returns "campaign not found" and an empty
  keyword section.
- **GA4 has no per-practice credential** — the service account is agency-wide; only the
  property ID is per practice, and the practice must grant it Viewer access.
- **A GA4 403 is ambiguous.** "Analytics Data API not enabled on the Cloud project" and
  "service account lacks Viewer access" are indistinguishable by status code. Read the JSON
  body.
- **GA4 makes two `runReport` calls on purpose.** Per-channel figures cannot be summed into
  sitewide totals without double-counting users who arrived via two channels, so totals
  come from a dimension-less report.
- **Yext keys report rows inconsistently** — sometimes by raw metric ID, sometimes by
  display name, within the same account. `metric_value` takes whatever value is left after
  excluding known dimension keys rather than guessing the label.
- **Yext sentiment metrics are fractions (0–1)**, not percentages, and are converted on
  read.
- **`ReportAiPlatformScore#platform` is deliberately not an enum** — Yext returns whatever
  model names it likes (`GEMINI`, `PERPLEXITY`), and new ones appear over time.
- **`GoogleAnalyticsAdapter` overrides `#call`, not `#perform`**, so it can give a specific
  reason rather than `Base`'s generic no-credentials message.
- **Only `Faraday::Error` is caught by `Base`.** Anything else propagates and fails the run
  — intentional, since a parse error is a bug rather than an outage.

### Not built yet

- **HubSpot and GHL are unverified against live accounts.** HubSpot's custom property names
  are a guess.
- **GHL agency-wide OAuth** is not built; Private Integration Tokens do not scale past one
  client, and Marketplace access is the blocker.
- **`credential_status` is never set.** Nothing tests a credential and records its health,
  so the Connections page labels are decorative.
- **No per-practice credential UI.** `external_id` and `override_credentials` are set only
  via `reports:seed_real_client` or the console.

---

## Changing this feature

- **An adapter must return a `Result`, never raise past `#call`.** The whole degradation
  model depends on it.
- **Never log a credential or a full API response.**
- **Never add a plaintext secret column** — use `encrypts`.
- **Per-practice credentials override agency-wide ones**, not the reverse.
- **Keep `Service::KEYS`, the `services` table and `AgencyConnection::CREDENTIAL_FIELDS` in
  step** when adding a service.
- **`badge_class` must stay a complete literal Tailwind class string**, never assembled
  from a colour name — Tailwind only compiles classes it can see literally in source.
