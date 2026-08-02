---
title: Google Analytics integration
slug: integration-google-analytics
status: shipped
last_verified: 2026-08-02
related: [integrations, monthly-report, report-generation]
---

# Google Analytics integration

> **Status:** shipped — verified against a real property · **Last verified:** 2026-08-02
>
> GA4 supplies the report's website traffic figures: visits, visitors, pages per visit, and
> the split by traffic source.

---

## For everyone

### Purpose

Every report opens with how many people visited the practice's website and where they came
from. That comes from Google Analytics 4.

### What it provides

| Report figure | Source |
|---|---|
| Total website visits | Sessions |
| Unique visitors | Total users |
| Pages per visit | Screen/page views per session |
| Organic / Direct / Referral / Paid split | Sessions grouped by channel |

### Setting it up

**GA4 is the odd one out.** Google does not issue simple API keys. It uses a **service
account** — a robot identity with an email address and a private key, created in Google
Cloud Console, which is a different product from Google Analytics itself.

- **Credential:** the service account's **client email** and **private key**, agency-wide,
  entered under Connections. One service account works for every practice.
- **Per practice:** the numeric **GA4 Property ID**, *and* the practice must grant that
  service account **Viewer** access on their property.

Full click-by-click steps, including who has to do the granting, are in
[MSP-GUIDE](../MSP-GUIDE.md#set-up-google-analytics-for-a-practice).

### When data is missing

| Situation | What the client sees |
|---|---|
| No property ID recorded | Visits show **—** and "Google Analytics isn't connected yet for this practice"; the traffic-sources breakdown is hidden entirely |
| Service account lacks Viewer access | Same, plus a permission warning in the generation log |
| The property has no data that month | Figures come back empty rather than zero, so the same placeholder shows |
| The call fails | Same placeholder; the rest of the report is unaffected |

### Known limits

- **Channels beyond the four shown still count toward the total.** Organic Social, Email
  and others contribute to total visits but are not broken out into their own figure, so
  the four listed sources will not sum to the total.

### FAQ

**Q: Why does GA4 need two fields when every other service needs one?**
A: Because Google does not offer an API key for this. The service account's email and
private key together are the credential.

**Q: Do we need a separate Google account per practice?**
A: No. One service account covers all of them. Only the property ID differs — plus a
one-time Viewer grant on each property.

**Q: We granted access but it still says not connected.**
A: Two different problems look identical. Confirm the Analytics Data API is enabled on the
Cloud project that owns the service account, *then* re-check the Viewer grant.

**Q: The four traffic sources don't add up to total visits.**
A: Correct and expected — visits from channels we do not break out are still in the total.

---

## For developers

### API reference

**Data API** `https://analyticsdata.googleapis.com`
**Token endpoint** `https://oauth2.googleapis.com/token`
**Scope** `https://www.googleapis.com/auth/analytics.readonly`

#### Authentication — service-account JWT bearer (RFC 7523)

No OAuth consent screen and no per-practice authorisation, unlike GHL. The adapter signs
its own assertion:

1. Build claims `{ iss: client_email, scope:, aud: <token endpoint>, exp: now+3600, iat: now }`.
2. Sign `base64url(header).base64url(claims)` with the private key, RS256.
3. `POST /token` with `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer` and the
   assertion.
4. Use the returned `access_token` as a Bearer token.

The token is memoized per `#perform`, so both report calls share one — minted fresh each
run rather than cached across runs, since they last an hour and a stale-token bug costs
more than a token mint.

#### Reports — `POST /v1beta/properties/{property_id}:runReport`

Called **twice**, and this is deliberate:

| Call | Metrics | Dimensions |
|---|---|---|
| Overview | `sessions`, `totalUsers`, `screenPageViewsPerSession` | *(none)* |
| Channel breakdown | `sessions` | `sessionDefaultChannelGroup` |

**Why not one call:** per-channel figures cannot be summed into sitewide totals. A user who
visits via both organic and direct in the same month would be counted twice in
`totalUsers`. So totals come from a dimension-less report, and the split from a
sessions-only report.

Body carries `dateRanges: [{ startDate, endDate }]` for the report month.

**Response shape:**

```
{ "rows": [ { "dimensionValues": [ { "value": "Organic Search" } ],
              "metricValues":    [ { "value": "200" } ] } ] }
```

Every value is a **string** and is cast on read.

### Field mapping

→ `ReportTraffic`

| Source | Column | Notes |
|---|---|---|
| `sessions` (overview) | `total_visits` | |
| `totalUsers` | `unique_visitors` | |
| `screenPageViewsPerSession` | `pages_per_visit` | Cast to float |
| channel `Organic Search` | `organic_visits` | |
| channel `Direct` | `direct_visits` | |
| channel `Referral` | `referral_visits` | |
| channels `Paid Search`, `Paid Social`, `Paid Video`, `Paid Shopping`, `Paid Other` | `paid_visits` | **Summed** |

An empty overview report yields `nil` for the three totals but **`0`** for `paid_visits`,
since summing over no matching channels gives zero. That asymmetry is asserted in the
tests.

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/google_analytics_adapter.rb` | Both report calls, plus all JWT signing |
| `app/models/agency_connection.rb` | `CREDENTIAL_FIELDS` — the only service with a `multiline: true` field |
| `app/views/shared/_form_group.html.erb` | Renders that multiline field as a textarea |
| `app/services/report_generator.rb` | `sync_traffic` writes the result |
| `app/presenters/report_presenter.rb` | `ga4_available?`, `visits_by_source`, `visit_share_pct` |
| `test/services/adapters/google_analytics_adapter_test.rb` | Generates a real RSA key to exercise signing |

### Data

Writes `total_visits`, `unique_visitors`, `pages_per_visit`, `organic_visits`,
`direct_visits`, `referral_visits`, `paid_visits` on `ReportTraffic`.

`ga4_available?` keys off `total_visits` being present — that one column decides whether
the whole traffic block renders or shows the placeholder.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| Missing property ID | `Result.failure("google_analytics: no GA4 property configured…")` | `error_log` |
| No credentials | `Base` returns a generic no-credentials failure | `error_log` |
| 403 — API not enabled on the Cloud project | `Result.failure` | `error_log` |
| 403 — service account lacks Viewer access | `Result.failure`, **indistinguishable by status code** | `error_log` |
| Empty property | `Result.success` with nil totals | Nothing — a real, valid answer |
| Malformed private key | `OpenSSL` raises — **not** a `Faraday::Error`, so the run fails | `status: "failed"` |

### Gotchas

- **A 403 is ambiguous.** "Analytics Data API not enabled on the owning Cloud project" and
  "service account lacks Viewer access" return the same status. Read the JSON body — and
  note Faraday's `raise_error` middleware normally swallows it.
- **`external_id` is the bare numeric ID** (`384938446`), not the `properties/384938446`
  path form the API itself uses. The adapter adds the prefix.
- **A service account cannot be logged into.** It has no browser session — you always act
  as a human in Cloud Console and *grant* the robot access.
- **You cannot swap `client_email` for a human Google account while keeping the key.** The
  key is cryptographically tied to that service-account identity; Google verifies the JWT
  signature against a public key registered for the claimed email, and a personal account
  has no such registration. The only route to leveraging a human account with broad access
  is Workspace domain-wide delegation, which requires actual Google Workspace.
- **Private keys survive being re-pasted with literal `\n`.** The adapter converts them, so
  a key pasted straight out of the downloaded JSON into an env var or the admin form works.
- **Never merge the two report calls.** The double-counting problem is real, not
  theoretical.
- **This adapter has no per-practice credential** — only the property ID is per practice.

### Not built yet

- No handling of GA4 sampling or quota limits.
- `ReportTraffic`'s `previous_*` traffic columns exist but are never written, so the report
  shows no month-over-month movement on traffic.

---

## Changing this feature

- **Keep the two report calls separate.**
- **Keep the credential agency-wide.** Per-practice service accounts would multiply the
  Cloud Console setup cost for no benefit.
- **Keep `ga4_available?` keyed on a real figure**, so an unconfigured practice degrades to
  the placeholder rather than showing zeros.
