---
title: The adapter layer
slug: integrations
status: shipped
last_verified: 2026-08-06
related: [integration-yext, integration-semrush, integration-google-analytics, integration-hubspot, integration-ghl, integration-anthropic, report-generation]
---

# The adapter layer

> **Status:** shipped · **Last verified:** 2026-08-06
>
> The shared machinery every external service goes through: credentials, timeouts, retries,
> and the contract that lets one dead API degrade one report section instead of failing the
> whole run.
>
> **Each service has its own document** — this one covers what they have in common.

---

## The six integrations

| Service | Provides | Verified live? | Document |
|---|---|---|---|
| **Yext** | Citations, AI visibility, Google Business Profile | Yes | [integration-yext](integration-yext.md) |
| **SEMrush** | Keyword rankings | Yes | [integration-semrush](integration-semrush.md) |
| **Google Analytics** | Website traffic | Yes | [integration-google-analytics](integration-google-analytics.md) |
| **HubSpot** | Practice details, AI SEO enrolment | **No** | [integration-hubspot](integration-hubspot.md) |
| **GoHighLevel** | Appointments, revenue | Yes | [integration-ghl](integration-ghl.md) |
| **Anthropic** | The written highlight banners | Yes | [integration-anthropic](integration-anthropic.md) |

The first five share the adapter contract below. **Anthropic does not** — it predates the
shared plumbing and is documented separately as a known divergence.

---

## For everyone

### Purpose

MSP holds none of this data itself. Every figure in a report comes from a service that
already tracks part of a practice's online presence. This layer is how the system talks to
all of them consistently.

### Two kinds of credential

- **Agency-wide** — one key MSP holds that works for every practice, managed under
  Connections in the admin panel.
- **Per practice** — each service identifies a practice by its own ID, recorded per
  practice. See [where each ID comes from](../MSP-GUIDE.md#where-each-id-comes-from).

A practice can also hold its own credential override for a service. That takes precedence
over the agency-wide one, but in normal operation it is unused.

### When data is missing

**No external service can break a report.** Every failure is contained to its own section.

| Situation | Effect |
|---|---|
| No credential configured | The service is skipped; its sections show placeholders |
| No per-practice ID recorded | Same — the service is not called |
| The service errors or times out | Warning recorded, that section left empty, rest of the report produced |
| The service is slow or briefly unreachable | Retried four times with widening gaps before giving up |

### FAQ

**Q: Do we need a separate account per practice?**
A: No. One agency credential per service covers every practice. Only the per-practice ID
differs — except Google Analytics, which also needs the practice to grant our service
account access.

**Q: A practice's section is empty. Is it us or them?**
A: Generation records a warning per service. An empty section almost always means a
credential or ID problem, not genuine inactivity.

---

## For developers

### The contract

Every adapter subclasses `Adapters::Base`, declares `SERVICE`, and implements `#perform`.

**Adapters return, never raise.** `Adapters::Result` is a
`Data.define(:success?, :data, :error)` with `.success` and `.failure` constructors. This
single decision is what makes graceful degradation possible — `ReportGenerator` collects a
warning and carries on rather than aborting.

`Base` owns four things:

1. **Credential resolution** — `ClientServiceLink#override_credentials` (per practice) wins
   over `AgencyConnection#encrypted_credentials` (agency-wide). Both are
   ActiveRecord-encrypted JSON blobs, decrypted transparently.
2. **The `#call` wrapper** — returns `Result.failure` when no credentials exist, otherwise
   delegates to `#perform` and converts any `Faraday::Error` into `Result.failure`.
3. **`external_id`** — the practice's identifier in that service.
4. **`month_range`** — via the `MonthlyRange` concern, shared with `ReportGenerator`.

**Only `Faraday::Error` is caught.** Anything else — a `JSON::ParserError`, an
`ArgumentError` from an enum — propagates and fails the run. That is deliberate: an API
being down is normal, a parse error is a bug.

### Partial degradation within one adapter

`Base#degrade(default) { ... }` runs a block and returns `default` if it raises
`Faraday::Error`. It exists for services where one product area can be down while others
work — in practice, Yext, where a practice without Scout must still get citations and
Google Business Profile data.

Use it for a **sub-fetch that is allowed to fail independently**. Do not wrap a required
call in it.

### HTTP policy

`Adapters::ConnectionBuilder.build` is the single Faraday factory for every outbound call in
the app — the five adapters **and** `SitemapScanner`, which hits a practice's own website
rather than an API.

| Setting | Value |
|---|---|
| Open timeout | 10s |
| Read timeout | 15s |
| Retries | 4, on `Faraday::TimeoutError` and `Faraday::ConnectionFailed` |
| Backoff | 2s, 4s, 8s, 16s |
| Error handling | `raise_error` middleware |

**The wide retry spacing is deliberate.** `Net::HTTP` commits to a single resolved address
per attempt and, unlike curl, never falls back to another address from a DNS round-robin
pool. A real retry therefore needs real spacing to have a chance at a fresh DNS answer,
since resolvers rotate record order between lookups but the OS cache holds an answer for a
while. Tightening the intervals silently reduces the retry to "try the same dead IP four
times".

It is one implementation precisely because it already drifted once: `SitemapScanner` had its
own copy with the same timeouts but no retry middleware at all.

### Key files

| Path | Role |
|---|---|
| `app/services/adapters/base.rb` | Credential resolution, `#call` contract, `degrade` |
| `app/services/adapters/result.rb` | The success/failure value object |
| `app/services/adapters/connection_builder.rb` | The one Faraday factory |
| `app/services/concerns/monthly_range.rb` | Month-as-Range, shared with `ReportGenerator` |
| `app/models/agency_connection.rb` | Agency credentials, field definitions, display metadata |
| `app/models/client_service_link.rb` | Per-practice `external_id` and override |
| `app/models/service.rb` | The valid service keys, backing the FK constraints |
| `app/services/report_generator.rb` | The only caller of any adapter |

### Data

| Model / table | Role |
|---|---|
| `Service` | Lookup table of valid keys; **primary key is the key string itself** |
| `AgencyConnection` | One row per service; `encrypted_credentials`, `credential_status`, `expires_at`, `last_verified_at` |
| `ClientServiceLink` | One per practice per service; `external_id`, optional `override_credentials` |

Invariants:

- `agency_connections.service` and `client_service_links.service` are **foreign keys to
  `services`** — this replaced the same hardcoded list duplicated across two enum
  declarations.
- `agency_connections.service` is unique; `client_service_links` is unique on
  `(client_id, service)`.
- Both credential columns use `encrypts`. **Never add a plaintext secret column.**
- `Service::KEYS` exists for code needing the list when the database was schema-loaded
  rather than migrated — the migration seeds the same values.

### Gotchas

- **`Service` has a string primary key** (`self.primary_key = "key"`), unlike every other
  model here.
- **Display metadata deliberately lives in Ruby, not the database.**
  `AgencyConnection::DISPLAY[:badge_class]` holds a complete literal Tailwind class string
  because Tailwind only compiles classes it can find as literal text in source — a
  DB-driven class name would never have its CSS generated.
- **`credential_status` uses `prefix: :credential`** because a bare `invalid` enum value
  would override Active Record's own `#invalid?`.
- **`expires_at` and `last_verified_at` exist on both credential tables but are never
  written.**
- **Anthropic is outside all of this** — its own Faraday connection, no retries, no
  timeouts, key from `ENV`. A known divergence, not a pattern to copy.

### Not built yet

- **`credential_status` is never set for most services.** GoHighLevel is the one exception
  — its agency-wide OAuth grant (see [integration-ghl](integration-ghl.md)) writes
  `credential_status`/`expires_at`/`last_verified_at` for real on every connect and refresh.
  Every other service still leaves these Connections-page labels decorative.
- **No per-practice credential UI.** `external_id` and `override_credentials` are set only
  via `reports:seed_real_client` or the console.
- **HubSpot is unverified** against a live account.
- **Anthropic is not folded into the shared plumbing.**

---

## Changing this feature

- **An adapter must return a `Result`, never raise past `#call`.** The whole degradation
  model rests on this.
- **Route every outbound call through `ConnectionBuilder`** so the timeout and retry policy
  cannot drift again.
- **Never log a credential or a full API response.**
- **Per-practice credentials override agency-wide ones**, never the reverse.
- **Keep `Service::KEYS`, the `services` table, and `AgencyConnection::CREDENTIAL_FIELDS`
  in step** when adding a service.
