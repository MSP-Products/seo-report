---
title: GoHighLevel integration
slug: integration-ghl
status: shipped
last_verified: 2026-08-07
related: [integrations, monthly-report, report-generation]
---

# GoHighLevel integration

> **Status:** shipped — verified against a real GHL Marketplace app and a live sub-account
> (Adams Dental Associates) · **Last verified:** 2026-08-07
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
| Appointments booked | Count of calendar events in the month, across every calendar on the practice's GHL location |
| Estimated revenue generated | Sum of won opportunities in the month |

The revenue figure gets the report's only "hero" treatment — a dark filled tile — because
it is the number practices care about most.

### Setting it up

- **Credential:** agency-wide, and it is **connect-once, not hand-typed.** Under
  Connections → GoHighLevel, an admin clicks **Connect to GoHighLevel** and authorizes once
  through GHL's own consent screen. From then on, every practice's data flows through that
  one grant — there is no access token to copy-paste, and none is ever shown back.
- **Per practice:** the GHL **location ID** (the sub-account ID). An admin can type this in
  by hand, or click **Find GHL match** on the Edit practice page to have the system suggest
  one by matching the practice's website against every GHL sub-account's own website — see
  [Location auto-match by domain](#location-auto-match-by-domain) below. Either way, nothing
  is linked until the admin saves the form.

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
| Linked, but the agency has never connected GHL (or the connection has failed) | **Nothing — report generation fails entirely** for that practice and month | `report_generation_logs` status `failed` |
| Linked but the call failed | **Nothing — report generation fails entirely** for that practice and month | `report_generation_logs` status `failed` |
| Linked and working | Real figures, revenue in the hero tile | `connected` |

**A linked practice is expected to have a working GHL connection.** Presence of the link
is still the enrolment signal, but it now carries weight: an unlinked practice degrades
gracefully (no scheduler, `?` placeholders), while a linked one that fails aborts the whole
report — it isn't rendered with placeholders. See
[report-generation](report-generation.md#when-data-is-missing) for why: HubSpot, GA4, Yext,
and SEMrush are unconditionally mandatory, and GHL/AI SEO are mandatory the moment a
practice opts in.

### Known limits

- **"Estimated revenue" means won opportunities updated in the month**, not revenue
  actually collected, and not revenue attributable to SEO specifically.
- **"Appointments booked" counts calendar events in the month**, which includes any event
  on any of that location's calendars, not only new patient bookings.

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

**Q: Do we need to reconnect GHL periodically?**
A: No, in normal operation. The agency-wide grant refreshes itself automatically every 4 hours
(`RefreshGhlTokenJob`, see [jobs-and-schedules](../reference/jobs-and-schedules.md)) and
report generation also refreshes on demand if that job somehow missed a cycle. Reconnecting
by hand is only needed if the grant is revoked on GHL's side, or a new scope is added to
`GhlOauthClient::SCOPES` (which forces a full reauthorization, same as the first connect).

**Q: A newly connected practice's appointments show 0 even though they use the
scheduler.**
A: Confirm the location ID is right, then check directly in GHL whether that location's
calendars actually have events in the target month — 0 is a real, correctly-computed
answer when there is genuinely no calendar activity, not necessarily a bug.

**Q: I clicked "Find GHL match" and got "No GHL location found matching this practice's
website."**
A: Either the practice's `website_url` doesn't exactly match the `website` field on any GHL
sub-account (check for a typo, a missing/extra `www.`, or the practice using a different
domain in GHL than on their real site), or the practice genuinely has no sub-account in this
agency's GHL account yet. Either way, type the location ID in by hand if you have it from
another source.

**Q: The suggested match is wrong.**
A: It's a suggestion, not an assignment — nothing is saved until you click **Save practice**.
Just type the correct ID into the field yourself instead of using the suggestion.

---

## For developers

### How it works

1. An admin visits `/connections/ghl/edit` and clicks **Connect to GoHighLevel**, which hits
   `Connections::GhlOauthController#authorize`.
2. That redirects to GHL's own consent screen
   (`https://marketplace.gohighlevel.com/oauth/chooselocation`), carrying `client_id`,
   `redirect_uri`, the requested `scope` list, a CSRF `state`, and `user_type: "Company"`.
3. The admin picks the agency account and authorizes. GHL redirects back to
   `#callback` with a `code` and the same `state`.
4. `#callback` verifies `state` (timing-safe compare, single-use session value), then calls
   `GhlOauthClient#exchange_code!`, which trades the code for an agency-level `access_token`
   + `refresh_token` and persists them onto the one `service: "ghl"` `AgencyConnection` row.
5. From then on, `GhlAdapter` mints a short-lived **location-scoped** token from that agency
   grant on demand (`GhlOauthClient#location_access_token!`) and uses it for the two
   report-data calls. `RefreshGhlTokenJob` also keeps the agency token itself from ever
   going stale between monthly report runs (see
   [jobs-and-schedules](../reference/jobs-and-schedules.md)).

### App identity vs. agency grant — stored in two different places

- **`client_id`/`client_secret`** (the Marketplace app's own registration, one per deploy,
  never rotates) live in Rails credentials/`ENV` — `Rails.application.credentials.dig(:ghl,
  :client_id)` falling back to `ENV["GHL_CLIENT_ID"]`, same pattern as
  `active_record_encryption.rb`. They never pass through a web form.
- **`access_token`/`refresh_token`/`company_id`/`expires_at`** (this agency's live,
  volatile grant) live in the existing `AgencyConnection#encrypted_credentials` JSON blob
  for `service: "ghl"` — the same columns every other agency-wide credential uses.

### GHL Marketplace app configuration — get this wrong and nothing above is reachable

The app's **Target User** setting is chosen once, at creation, and **cannot be changed
afterward**. Two combinations look plausible; only one actually works:

| Target User | Who can install | Result |
|---|---|---|
| Agency | — | Calendars, Opportunities, and `oauth.write`/`oauth.readonly` are **permanently
  greyed out** — this app can never request them, no matter what's checked |
| **Sub-Account** | **Agency Only** | The scopes above become selectable, **and** the
  resulting install/token is still a single agency-level (`userType: "Company"`) grant —
  the "authorize once, mint per-location tokens" model this feature relies on |

If an app is ever created with Target User: Agency, it cannot be fixed — abandon it and
create a new one with the correct combination.

The redirect URI also cannot contain the literal substring `"ghl"` or `"highlevel"` — GHL's
own white-label validation rejects it ("The redirect uri contains a HighLevel reference.").
That's why the route path is `/connections/scheduler/authorize` /
`/connections/scheduler/callback` rather than `.../ghl/...`, even though every Ruby-side
name (`GhlOauthClient`, `GhlOauthController`, the `ghl_authorize`/`ghl_callback` route
helpers) keeps the real name — only the URL string had to change.

### API reference

**Base URL** `https://services.leadconnectorhq.com` (GHL v2)
**Auth** `Authorization: Bearer <token>` **and** `Version: 2021-07-28`

The `Version` header is mandatory on v2 — omitting it fails the request.

#### OAuth — `POST /oauth/token`

| `grant_type` | Body params |
|---|---|
| `authorization_code` | `code`, `redirect_uri`, `client_id`, `client_secret`, `user_type: "Company"` |
| `refresh_token` | `refresh_token`, `client_id`, `client_secret`, `user_type: "Company"` |

Response includes `access_token`, `refresh_token`, `expires_in` (seconds — GHL's agency
tokens last 24h), and `companyId`. **The refresh token rotates on every use** — the
response's new `refresh_token` must replace the stored one every time, or the connection is
bricked on the very next refresh attempt.

#### OAuth — `POST /oauth/locationToken`

Mints a location-scoped token from the agency-level one.

| Param | Value |
|---|---|
| Header `Authorization` | `Bearer <agency access_token>` |
| `companyId` | from the stored agency grant |
| `locationId` | the practice's GHL location ID |

#### Appointments — `GET /calendars/` then `GET /calendars/events`

GHL's `/calendars/events` has **no "all events for this location" mode** — it requires
filtering by one of `calendarId`/`userId`/`groupId` (confirmed live: querying without one
422s with `"Either of userId, calendarId or groupId is required"`). So this is two calls,
not one: list the location's calendars, then sum each one's event count for the month.

| Call | Parameter | Value |
|---|---|---|
| `GET /calendars/` | `locationId` | the location ID |
| `GET /calendars/events` (once per calendar) | `locationId` | the location ID |
| | `calendarId` | one ID from the calendars call |
| | `startTime` / `endTime` | month start/end, **epoch milliseconds** |

Reads `events` per calendar and sums each call's **size**. The count is the metric; no
event detail is stored. Listing calendars itself needs the `calendars.readonly` scope —
distinct from `calendars/events.readonly`, which only covers the events call.

#### Revenue — `GET /opportunities/search`

| Parameter | Value |
|---|---|
| `location_id` | the location ID — **snake_case** |
| `status` | `won` |
| `date` | month start, **`mm-dd-yyyy`** |
| `endDate` | month end, **`mm-dd-yyyy`** |

Reads `opportunities` and sums `monetaryValue`.

**GHL's own Marketplace docs page for this endpoint disagrees with the deployed API**, and
this cost real debugging time to work out: the docs show a camelCase `locationId` param,
but the live endpoint rejects that outright (`"property locationId should not exist"`) and
requires snake_case `location_id`. A reasonable-looking first guess at date filtering
(`date_updated_start`/`date_updated_end`) also 422s (`"property ... should not exist"`) —
the real params are the plain `date`/`endDate` pair above, in `mm-dd-yyyy`, not ISO 8601.
**When the deployed API and the docs disagree, trust a live call, not the docs page.**

**Note the inconsistency between the two report-data endpoints** — it is GHL's, not ours,
and it is easy to get wrong when adding a third call:

| | Appointments | Revenue |
|---|---|---|
| Location parameter | `locationId` (camelCase) | `location_id` (snake_case) |
| Date format | epoch milliseconds | `mm-dd-yyyy` |

### Token lifecycle

- **Agency access tokens last ~24h**; refresh tokens are long-lived and rotate on every
  use.
- `GhlOauthClient::EXPIRY_BUFFER` is **12 hours** — deliberately wider than
  `RefreshGhlTokenJob`'s 4-hour cadence, so the job always catches a token before it
  actually expires rather than leaving that entirely to the lazy refresh below. The wide
  buffer is also what makes `last_verified_at` a meaningful "still healthy" signal: a real
  refresh happens roughly every 12 hours, not only once near the token's actual ~24h expiry.
- `GhlOauthClient#location_access_token!` (called by `GhlAdapter` during report generation)
  refreshes lazily if the stored token is stale, as a backstop — but `RefreshGhlTokenJob`
  running every 4 hours means this should rarely be the thing that actually triggers a
  refresh in practice.
- A refresh failure (e.g. the grant was revoked in GHL) sets `credential_status: "expired"`
  and re-raises — surfaced on the Connections page, and it will fail generation for any
  practice linked to GHL until an admin reconnects.

### Location auto-match by domain

`GhlLocationMatcher` (`app/services/ghl_location_matcher.rb`) suggests a GHL location for a
`Client` by matching each of the agency's sub-accounts' own `website` field against the
practice's `website_url` — a suggestion for an admin to confirm on the Edit practice page,
never a silent auto-assign. Triggered by a **Find GHL match** button, scoped to persisted
clients only (a brand-new, unsaved client has no ID to hang the lookup route off of).

**Endpoint** — `GET /locations/search` (agency-token scoped; no per-location token mint
needed, unlike the two report-data calls above):

| Parameter | Value |
|---|---|
| `companyId` | the agency's own company ID, from the stored grant |
| `skip` / `limit` | pagination — `limit: 100` confirmed live (GHL's docs only document a default of 10, not a documented maximum) |

Response shape: `{ "locations": [ { "id", "name", "website", "domain", ... } ] }`. **`website`
is the field to match on** — it carries the practice's real site URL (e.g.
`https://www.adamsdentalassociates.com/`). There's a separate `domain` field on the same
object, but it was blank on every real location checked — it isn't the practice's own site.

**Matching is exact, not fuzzy** — both sides are normalized (strip `https?://`, strip
`www.`, strip a trailing slash, downcase — the same shape as
`SemrushAdapter#tracked_url_mask`, copied rather than shared: this is only the second
occurrence, and the rule of three says extract on the third, not the second) and compared
for equality. No partial-match ranking, no Levenshtein distance — a mismatch just means "no
match," not "closest match."

**How it's wired up:**

1. `Clients::GhlLocationMatchesController#create` (`POST
   /clients/:client_id/ghl_location_match`) calls `GhlLocationMatcher.new(@client).call` and
   re-renders `clients/edit` with the result in `@ghl_suggested_match` — a `Match` (found), or
   `false` (checked, nothing found). It never touches `@client.client_service_links` or saves
   anything.
2. `rescue_from Faraday::Error, GhlOauthClient::NotConnectedError` catches a genuine API
   failure and flashes a generic alert instead — this is what lets the view distinguish
   "checked, found nothing" (`false`) from "couldn't check at all" (`@ghl_suggested_match`
   stays unset, no caption renders, alert shows instead).
3. The view shows the match's name/website/location ID as plain text (readable and
   copy-pasteable with no JavaScript at all) plus a **Use this** button that fills the
   adjacent `external_id` field client-side
   (`app/javascript/controllers/apply_suggestion_controller.js`, a small Stimulus controller
   in the same size class as `copy_controller.js`). Either way, the admin still has to click
   **Save practice** to actually persist it — same as typing the ID in by hand.

**A real HTML gotcha this surfaced, worth not repeating:** the trigger button cannot be a
`button_to` (or any element rendering its own `<form>`) nested inside the main
`_form.html.erb`'s `form_with` block. Nested `<form>` elements are invalid HTML, and browsers
handle the resulting stray closing tag by silently closing the **outer** form early —
which would have orphaned **Save practice** outside any form entirely (clicking it would do
nothing). The fix: a standalone, empty `form_with` (`id="ghl_location_match_form"`) rendered
*before* the main form opens, and a plain `button_tag ..., form: "ghl_location_match_form"` —
HTML5's `form=""` attribute lets a button submit a form it isn't nested inside, with no
JavaScript involved. See `app/views/clients/_form.html.erb`.

**Route note:** `resource :ghl_location_match, only: [:create]` nested under `resources
:clients` puts the parent id under `params[:client_id]`, not `params[:id]` — `FindsClient`'s
`set_client` checks both (`params[:id] || params[:client_id]`), so every existing caller is
unaffected and this one new controller works without its own loader.

### Local dev testing — the real API, no stub

**`http://localhost:3000/connections/scheduler/callback` is registered as an allowed redirect
URI on the GHL Marketplace app, alongside production's.** There is no stub, and none is
needed: GHL accepts a plain `http://localhost` redirect fine — the earlier assumption that it
required `https` (and the ngrok-tunnel/fake-credential workarounds built on that assumption)
was wrong, confirmed by testing the real flow end to end. `GhlOauthClient#authorize_url`
always builds the real GHL consent URL; `VerifiesGhlOauthState#set_oauth_state` computes the
redirect URI from whatever host the admin is actually browsing on
(`request.base_url` + `connections_ghl_callback_path`), so it's automatically correct in every
environment as long as that exact URL is on GHL's allowed-redirects list.

To connect for real locally: enter this project's real `GHL_CLIENT_ID`/`GHL_CLIENT_SECRET` in
`.env` (loaded by `foreman` via `bin/dev`), then click **Connect to GoHighLevel** on the
Connections page — it redirects to GHL's real consent screen and back, same as production.

### Recovery: moving a GHL connection between environments

The agency-level grant is the same GHL company regardless of which environment's database
holds it, so a token pair obtained in one environment can be copied directly into another
environment's `AgencyConnection` row — useful if an environment's refresh token goes invalid
(revoked, or expired from long disuse) and reauthorizing there directly isn't convenient:

```bash
# on the source environment (e.g. production, via Railway's console)
bin/rails ghl:print_connection
# copy the printed JSON, then on the target environment:
GHL_CONNECTION_JSON='<pasted json>' bin/rails ghl:import_connection
```

See `lib/tasks/ghl.rake`. **The printed JSON contains a live access_token/refresh_token** —
handle it like any other credential. `ghl:print_connection` should only ever be run directly
by a human in their own terminal, never piped through a channel that might log or display
it — that's exactly the mistake to avoid (see Gotchas).

### Field mapping

→ `ReportTraffic`

| Source | Column |
|---|---|
| Sum of each calendar's `events.size` | `appointments_booked` |
| `sum(opportunities[].monetaryValue)` | `estimated_revenue` |
| *constant* `"connected"` | `ghl_data_status` |

`ghl_data_status` is set to `not_connected` (no link) by `ReportGenerator` before ever
calling this adapter, or to `"connected"` after a successful call — those are the only two
values now. A failed call never reaches `traffic.save!`; `ReportGenerator` raises first, so
no third `ghl_data_status` value is ever written (see
[report-generation](report-generation.md)).

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/ghl_oauth_client.rb` | The whole OAuth lifecycle: authorize URL, code exchange, refresh, location-token minting |
| `app/controllers/connections/ghl_oauth_controller.rb` | `authorize`/`callback` actions |
| `app/controllers/concerns/verifies_ghl_oauth_state.rb` | CSRF `state` guard, `require_editor!`, the `AuthorizationError` rescue |
| `app/jobs/refresh_ghl_token_job.rb` | Proactive refresh, every 4 hours (see [jobs-and-schedules](../reference/jobs-and-schedules.md)) |
| `app/services/adapters/ghl_adapter.rb` | Both report-data calls |
| `app/services/report_generator.rb` | `sync_traffic` — sets `not_connected` without calling, or raises on a linked call's failure |
| `app/models/agency_connection.rb` | `oauth_managed?`, empty `CREDENTIAL_FIELDS["ghl"]`, the `status_label` exception for OAuth-managed services |
| `app/models/report_traffic.rb` | The two-value `ghl_data_status` enum |
| `app/presenters/report_presenter.rb` | `ghl_connected?` — drives the `?` placeholder |
| `app/views/reports/_traffic.html.erb` | The `?` placeholders and explanatory callout |
| `app/views/connections/edit.html.erb` | Renders status + Connect/Reauthorize instead of a field form, for `oauth_managed?` services |
| `config/routes.rb` | `/connections/scheduler/authorize` / `/connections/scheduler/callback` (path avoids GHL's brand-reference check; route helpers stay `ghl_*`) |
| `config/initializers/filter_parameter_logging.rb` | Filters `:code` so the callback's query string never lands unredacted in logs |
| `app/services/ghl_location_matcher.rb` | Paginated `/locations/search` + domain-normalized matching |
| `app/controllers/clients/sync_services_controller.rb` | `create` — GHL is now checked alongside Yext and SEMrush by one **Sync services** action rather than a GHL-only button; see [client-onboarding](client-onboarding.md) |
| `app/services/sync_services_checker.rb` | Runs `GhlLocationMatcher` for a client whose GHL `external_id` is blank, isolating its failure from the other services' |
| `app/controllers/concerns/finds_client.rb` | `set_client` — accepts `params[:client_id]` (the nested-resource param) as well as `params[:id]` |
| `app/views/clients/_form.html.erb` | The GHL row's suggestion caption + the standalone `sync_services_form` (see Gotchas) |
| `app/javascript/controllers/apply_suggestion_controller.js` | Click-to-fill the suggested location ID; JS optional, the ID is always visible as plain text too |
| `lib/tasks/ghl.rake` | `ghl:print_connection` / `ghl:import_connection` — the cross-environment recovery path |
| `test/services/ghl_oauth_client_test.rb` | Code exchange, refresh + rotation, `refresh_if_stale!`, `agency_access_token!`, failure paths |
| `test/controllers/connections/ghl_oauth_controller_test.rb` | State mismatch, successful callback, role gate |
| `test/services/adapters/ghl_adapter_test.rb` | Both calls, the per-client override path, the missing-location-id case |
| `test/jobs/refresh_ghl_token_job_test.rb` | Delegates to `refresh_if_stale!`; no-op when never connected |
| `test/models/agency_connection_test.rb` | `oauth_managed?`, `status_label` branching |
| `test/services/ghl_location_matcher_test.rb` | Match found (incl. across pagination), no match, blank `website_url`/missing `company_id` short-circuit without an HTTP call, HTTP failure propagates |
| `test/controllers/clients/sync_services_controller_test.rb` | Enqueues the check, the per-service "Searching…" turbo_stream response, `support` role blocked |
| `test/services/sync_services_checker_test.rb` | GHL's failure isolated from Yext/SEMrush, already-linked services skipped |

### Data

Writes `appointments_booked`, `estimated_revenue` (decimal, precision 12 scale 2) and
`ghl_data_status` on `ReportTraffic`.

**The link's existence is the enrolment record.** `ReportGenerator` checks
`client.client_service_links.exists?(service: "ghl")` before constructing the adapter at
all.

**A per-client `ClientServiceLink#override_credentials` access_token, if present, is used
as-is** — no call to any OAuth endpoint at all for that client. This is the pre-OAuth
workaround (a raw Private Integration Token pasted into a client's Sources tab) and it still
works unchanged; the OAuth grant is only the fallback when no override exists.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| No `ClientServiceLink` for `ghl` | Adapter **never constructed**; `ghl_data_status: "not_connected"` | Nothing — a normal state |
| Link exists, `external_id` blank | `Result.failure("ghl: no location id configured…")` → `ReportGenerator` raises | `report_generation_logs` status `failed` |
| Linked, but agency never connected GHL (no `refresh_token` on record) | `GhlOauthClient::NotConnectedError` → `Result.failure` → raises | `report_generation_logs` status `failed` |
| Agency token refresh fails (grant revoked) | `credential_status: "expired"`, error re-raised → `Result.failure` → raises | `report_generation_logs` status `failed`; Connections page shows "Expired" |
| HTTP error after retries | `Result.failure` → `ReportGenerator` raises | `report_generation_logs` status `failed` |
| Missing `Version` header | Request rejected by GHL → `Result.failure` → raises | `report_generation_logs` status `failed` |
| OAuth `state` mismatch on callback | Redirects with a generic alert; no token exchange attempted | Nowhere — never reaches persistence |
| Code exchange fails (bad/expired code) | `GhlOauthClient::AuthorizationError`, generic message, flashed | Nowhere — deliberately no raw GHL response in the message |

### Gotchas

- **Absence of a link is meaningful, not merely missing config.** Linking a practice
  changes what their report asserts about them, so do not link one "to see if it works".
- **Target User: Agency is a dead end, and it's irreversible.** See "GHL Marketplace app
  configuration" above — confirm Target User: Sub-Account + Agency Only install *before*
  finishing app creation.
- **The redirect URI can't contain "ghl"/"highlevel".** Only the URL path was renamed to
  work around this; every Ruby-side name stays `Ghl*`/`ghl_*`.
- **`/calendars/events` has no "list everything for this location" mode** — always list
  calendars first.
- **`calendars.readonly` and `calendars/events.readonly` are two separate scopes.** Having
  one does not grant the other.
- **`/opportunities/search`'s real params (`location_id` snake_case, `date`/`endDate` in
  `mm-dd-yyyy`) contradict GHL's own docs page for the same endpoint.** Don't "fix" this
  back to match the docs without re-confirming live first — see API reference above.
- **The two report-data endpoints don't even agree with each other** on location-param
  casing or date format — copying one call's shape for a third call will fail.
- **`Version: 2021-07-28` is required** on every v2 request.
- **Epoch values for `/calendars/events` are milliseconds**, hence the `* 1000`.
- **The refresh token rotates every use.** Persisting the old one instead of the new one
  bricks the connection on the next refresh.
- **`EXPIRY_BUFFER` (12 hours) is intentionally wider than `RefreshGhlTokenJob`'s 4-hour
  cadence** — if the job's schedule ever changes, this buffer needs to stay ahead of it.
- **The adapter never returns a non-`connected` status** — that distinction is
  `ReportGenerator`'s, which is why `sync_traffic` has branching that looks redundant but
  is not.
- **A linked practice's GHL failure now fails the whole report**, not just this section.
  There is no "linked but degraded" state — see [report-generation](report-generation.md).
- **`monetaryValue` is coerced with `to_f`**, so a missing or non-numeric value contributes
  zero rather than raising.
- **Never nest a `button_to` (or anything else rendering its own `<form>`) inside
  `_form.html.erb`'s main `form_with`.** It's invalid HTML, and the browser resolves it by
  closing the *outer* form early — which silently breaks **Save practice**, not just the
  nested control. Use the `form=""` attribute pattern instead (see Location auto-match by
  domain, above).
- **`ghl:print_connection` prints a live access_token/refresh_token to stdout.** Only ever
  run it directly in a human's own terminal — piping it through any tool or channel that
  logs/displays its output is a real credential exposure, not a hypothetical one.
- **The Locations API's `domain` field is not the practice's website** — it was blank on
  every real location checked. Match on `website`.

### Not built yet

- **`GhlOauthClient#authorize_url` doesn't send GHL's `version_id` param**, which its own
  "Install Link" includes. This is currently masked because the Marketplace app is
  Published (a Draft app's own OAuth flow silently bounced back to `agency_dashboard` with
  no visible error, until installed via that Install Link) — whether `version_id` is needed
  for full robustness on a Draft app is unresolved.
- **No disconnect/revoke action** in the admin UI — only Connect and Reauthorize.
- **No admin-visible alert on a `RefreshGhlTokenJob` failure** beyond the Connections page's
  `credential_status` — consistent with the rest of the app (see
  [Observability](../../CLAUDE.md#observability-and-operations)), but worth knowing this is
  the one place a silent failure would first surface.
- No appointment or opportunity detail is stored, only the aggregates.
- **Location auto-match is a suggestion only** — there's no bulk "match every unlinked
  practice" action, only the one-at-a-time button on Edit practice. Confirmed via the full
  service/controller test suite and a live `/locations/search` call against the real agency
  account; not yet separately confirmed end-to-end through a live click in a browser.

---

## Changing this feature

- **Keep link-presence as the enrolment signal**, or introduce an explicit flag and migrate
  deliberately — but do not have both.
- **A linked practice's GHL call must be mandatory.** Don't reintroduce a degrade path for
  "linked but failed" — that decision was deliberately reversed (see
  [report-generation](report-generation.md#changing-this-feature)).
- **Never call GHL for an unlinked practice.** The check exists so an unenrolled practice
  costs nothing and never blocks their report.
- **Never recreate the Marketplace app with Target User: Agency.** It cannot be changed
  afterward and permanently loses access to Calendars/Opportunities/`oauth.write`.
- **Keep `client_id`/`client_secret` out of the encrypted per-connection blob** — they are
  the app's own identity, not this agency's grant, and belong in credentials/`ENV`.
- **Keep honoring a per-client `override_credentials` token as-is**, with no call to any
  OAuth endpoint, before falling back to the agency grant.
- **Re-confirm any new GHL query parameter against a live call**, not just the Marketplace
  docs page — this integration has two confirmed cases of the docs being wrong.
- **Location auto-match must stay a suggestion, never a silent auto-assign.** Any change
  here must still require the admin to click Save practice before anything is persisted.
- **Never add a second `<form>` element nested inside `_form.html.erb`'s main form.** Use
  the `form=""` attribute pattern for any future standalone action on that page.
