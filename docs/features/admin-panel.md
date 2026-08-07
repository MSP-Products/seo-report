---
title: Admin panel
slug: admin-panel
status: partial
last_verified: 2026-08-07
related: [integrations, report-generation]
---

# Admin panel

> **Status:** partial — login, Dashboard, Connections, and Clients work; admin user
> management and credential verification are still missing ·
> **Last verified:** 2026-08-07
>
> The internal, logged-in side of the system: who can get in, and what they see once
> they're in.

---

## For everyone

### Purpose

MSP staff need somewhere to see whether this cycle's reports are generating, and to manage
the API credentials reports are built from, without a developer editing a config file or
running a console command. The admin panel is that place.

It is deliberately small. Today it shows the current reporting cycle's status, manages
agency-wide credentials, and manages the practice list itself — most other operational
tasks are still a command. See [MSP-GUIDE](../MSP-GUIDE.md).

### Who uses it

**MSP staff only.** Practices never see it. Two roles:

| Role | Can |
|---|---|
| **admin** | View everything and change API credentials, practices, and data sources |
| **support** | View everything, change nothing |

### How it behaves

1. Go to `/login`, enter email and password.
2. Landing page is **Dashboard** — this cycle's client counts, generation progress, and
   per-service connection health, all real data.
3. **Clients** lists every practice, searchable by name and filterable by onboarding
   status, each row showing its enrollments, HubSpot sync status, latest report, and
   delivery status. Clicking a practice opens Overview / Reports / Keywords / Data sources
   tabs.
4. **Add client** takes either a HubSpot company ID (which syncs the rest automatically) or
   manually typed details, or both.
5. **Edit practice** is where an admin enters or changes any of the five services' IDs, and
   where HubSpot sync status is visible per practice.
6. **Report Log** lists every generated report across every practice and month, filterable
   by month, with a link to view each ready report.
7. **Connections** lists all five services with a status; an admin clicks **Edit**, enters
   the credential, and saves.
8. A support user clicking an Edit/Add link on any of these pages is redirected with a
   permission message.
9. Log out from the sidebar.

**There is no sign-up page and no password reset.** Accounts are created by a developer.

**Credential fields always render blank**, even when a value is stored — a saved secret can
never be read back out of the page. **Leaving a field blank keeps the existing value**; you
only type into it to replace one.

**Adding or editing a practice takes either path, or both.** The form has no required
field except a name — and even the name becomes optional the moment a HubSpot company ID
is entered, since saving with one immediately triggers a sync that fills in the name (and
address, website, onboarding status, and AI SEO enrolment) from HubSpot. Until that first
sync succeeds, a newly-created client shows a placeholder name ("Syncing from HubSpot…")
that the sync overwrites within moments.

**`onboarding_status`, `onboarded_at`, and `ai_seo_enrolled` are read-only on this form.**
They are shown in a "Reporting" panel, each tagged with the source system (HubSpot or
GoHighLevel), because `SyncClientFromHubspot` overwrites them from HubSpot on every report
run — letting an admin type a value here would just have it silently clobbered on the next
sync. A practice's onboarding status genuinely stays "Pending" until a real HubSpot sync
succeeds; there is no way to force it to "Active" from this UI, by design.

**Changing a HubSpot company ID re-syncs immediately** (`ClientServiceLink`'s
`after_commit` callback enqueues `SyncHubspotClientJob`), rather than waiting for the daily
`EnqueueHubspotSyncJob` run, and clears the link's previous `last_synced_at`/
`last_sync_error` so the UI doesn't show a stale result from the ID that was just replaced.
There is no separate "sync now" control — saving the form is the trigger.

**The Data sources section is the same list on both Add client and Edit practice** —
one row per service (HubSpot, GoHighLevel, Yext, SEMrush, Google Analytics), each an ID
field plus a status dot. HubSpot's row additionally shows its live sync state (Syncing… /
Synced *n* ago / Sync failed, with a plain-language reason on failure) since it's the one
service whose ID drives more than report data. **GoHighLevel's row, on Edit practice only,**
additionally has a **Find GHL match** action that suggests a location ID by matching the
practice's website against every GHL sub-account's own — a suggestion only, never a silent
auto-assign; the admin still has to click Save practice to persist it. See
[integration-ghl](integration-ghl.md#location-auto-match-by-domain).

**The Clients index's "HubSpot sync" column mirrors the Edit page's status**, so an admin
scanning the whole list can see which practices are mid-sync or failing without opening
each one.

**The Dashboard shows, for the last completed month:** active/pending client counts;
reports generated vs. total active clients, with a Running/Completed badge; reports sent
vs. held (with the real hold reason, e.g. "HubSpot token rejected"); average generation
time per report; a live "generating" card naming whichever client is currently being
processed, with a progress bar and start time, while a run is in progress; a per-client
table for the cycle, including any active client the run hasn't picked up yet; and the same
per-service health already shown on Connections.

**Report Log is read-only and unfiltered by default** — every report, every practice, newest
month first, with an "All months" option and a per-month filter. Only a `ready` report gets
a "View" link; a queued, generating, or failed one has nothing to click through to.

**Status filtering uses `MonthlyReport#effective_status`, not the bare `generation_status`
column.** It folds send state into generation state — `sent`/`held` only mean anything once
a report is `ready` — into one set of six mutually exclusive values, so the filter chips show
one clean count each instead of two overlapping dimensions (generation status and send
status) double-counting the same report:

| `effective_status` | True when |
|---|---|
| `queued` | `generation_status == "queued"` |
| `generating` | `generation_status == "generating"` |
| `failed` | `generation_status == "failed"` |
| `sent` | `ready?` and `emailed_at` present |
| `held` | `ready?`, not emailed, and a `send_logs` row has `status: "held"` |
| `ready` | `ready?`, not emailed, not held |

### When data is missing

| Situation | What's shown |
|---|---|
| A service has no credential saved | "Not configured", grey dot |
| A credential is saved but never verified | "Unverified" |
| A practice has no HubSpot company ID | "Not linked", grey dot, on both the index and Edit page |
| A practice's HubSpot sync is enqueued but hasn't completed yet | "Syncing…", amber dot |
| A practice's most recent HubSpot sync failed | "Sync failed" plus a plain-language reason (bad ID, no access, timeout, etc.), red dot |
| A service has no configurable fields | "Not available yet", and Edit is hidden |
| An active client has no report row for the cycle yet | Shown on the Dashboard as "Not started", never omitted |
| A report is ready but hasn't been emailed | "Not sent" — there is no mailer yet, so this is the default, not a failure |

**The health labels — Active, Expiring soon, Expired, Needs attention — are never set
automatically.** Nothing tests a credential and records its state, so they are decorative
today. The reliable check is to generate a report and read its warnings.

### Client lifecycle: Offboarding and recovery

When a practice ends their engagement, they can be **offboarded** (soft-deleted) rather than
permanently removed. Offboarded clients are hidden from the active client list and don't
generate reports, but their history remains queryable if they ever return.

**Offboarding a client:**
1. Go to **Clients** → find the practice
2. Click the **Actions menu** (three dots) → **Offboard** (desktop) or the archive icon (mobile)
3. Confirm the dialog
4. The client moves to the "Offboarded" tab on the Clients list and disappears from Active
5. Their report history remains visible on the client's own page

**Recovering an offboarded client:**
1. Go to **Clients** → click the **Offboarded** tab
2. Find the practice
3. Click the **Actions menu** → **Recover**
4. A warning dialog explains that HubSpot will automatically sync in ~1 hour and may re-offboard them if they're still marked that way in HubSpot (protecting against accidental recovery of practices HubSpot thinks are offboarded)
5. If you proceed, the client re-appears in the Active tab

**Permanently deleting a client:**
1. Go to **Clients** → **Offboarded** tab (can only delete offboarded clients, never active ones)
2. Find the practice
3. Click the **Actions menu** → **Delete permanently**
4. Confirm the dialog — this **cannot be undone**
5. The client, all their reports, and all their history are permanently removed

**Why soft-delete first?** Separating offboarding (hidden, reversible) from permanent deletion
(irreversible) protects against accidents. You can offboard a client without fear, recover them
at any time, and only permanently delete if you're certain they're never coming back.

---

### FAQ

**Q: How do I get an account?**
A: A developer creates it. There is no self-service sign-up.

**Q: I forgot my password.**
A: A developer sets a new one. There is no reset email.

**Q: Why can't I see the existing API key?**
A: By design — stored credentials are never rendered back to the browser. If you need to
know a key's value, get it from the source service, not from here.

**Q: I saved a credential. Is it working?**
A: The page cannot tell you. Generate a report for a practice using that service and read
the warnings.

**Q: Why does Google Analytics need two fields when the others need one?**
A: Google does not issue simple API keys. It uses a service account with an email and a
private key. See [MSP-GUIDE](../MSP-GUIDE.md#set-up-google-analytics-for-a-practice).

---

## For developers

### How it works

**Authentication** is session-based and hand-rolled, not Devise. `AdminUser` uses
`has_secure_password`. `SessionsController#create` looks the user up by downcased email and
calls `#authenticate`; success stores `session[:admin_user_id]`.

`ApplicationController` applies `before_action :authenticate_admin!` app-wide, so every
controller is protected unless it opts out — `ReportsController` and the login actions do.
`require_editor!` is the write gate, opted into per controller with `only:`.

**Connections** is a five-row list built by mapping over `AgencyConnection.services.keys`
and using `find_or_initialize_by`, so unsaved services still render. `#update` merges only
non-blank submitted values into the existing credentials blob before re-serialising — this
is what implements "blank means unchanged".

**Clients** — `PaginatedClientsQuery` wraps the `Client.kept.search.by_status` scope chain
for the index. The Add/Edit form is one partial (`clients/_form`) shared by both actions,
using `accepts_nested_attributes_for :client_service_links` so all five services' IDs save
in the same request as the practice's own fields — `Client#service_links_for_form` returns
one row per `Service::KEYS`, existing or a built stub, so every service always has an input.
`Client#set_placeholder_name_for_hubspot_sync` (a `before_validation`) is what lets `name`
stay blank when a HubSpot ID is present — it fills in a placeholder that the sync's own
`client.update!` overwrites moments later. The actual sync trigger lives on `Client`, not the
controller: `after_commit :sync_linked_services` walks every one of the client's
`client_service_links` after each save (nested attributes mean one submission can touch
several at once) and, for each with a present `external_id`, enqueues `SyncHubspotClientJob`
for the HubSpot link or `TestClientServiceConnectionJob` (a lightweight connection check, not
a full data pull) for any other linked service — not gated on which specific field changed,
so an untouched link's stale result still gets refreshed by the same save.
`ClientServiceLink#before_save :reset_sync_status` clears `last_synced_at`/`last_sync_error`
whenever a link's `external_id` changes, so the previous ID's result doesn't sit on screen
until the re-verification completes. `SyncClientFromHubspot#record_attempt` and
`LinkedServiceConnectionTester.record_attempt` are what write `last_synced_at`/
`last_sync_error` back onto the link after each attempt, success or not.

`Adapters::HubspotAdapter::PROPERTIES` names the exact HubSpot Company properties fetched
— `name`, `address`, `website`, `active`, `gmb_seo_start_date`, `service_purchased` — and
maps them: `active` (a plain boolean, no separate "pending" state in HubSpot) → `"active"`
if true else `"offboarded"`; `gmb_seo_start_date` → `onboarded_at`; `service_purchased`
(HubSpot's semicolon-delimited multi-select) → `ai_seo_enrolled` if it contains the literal
tag `"AI SEO"` (`HubspotAdapter::AI_SEO_TAG`). `name`/`address`/`website` map straight
across. See [integrations](integrations.md) for the adapter's credential resolution and
error handling.

### Key files

| Path | Role in this feature |
|---|---|
| `app/controllers/application_controller.rb` | `authenticate_admin!`, `require_editor!`, `current_admin_user` |
| `app/controllers/sessions_controller.rb` | Login and logout |
| `app/controllers/connections_controller.rb` | The credentials list and form |
| `app/models/admin_user.rb` | `has_secure_password`, role enum, email normalisation |
| `lib/tasks/admin_users.rake` | `admin_users:create` — the supported way to create an account, ENV-driven so nothing sensitive is committed |
| `app/models/agency_connection.rb` | `CREDENTIAL_FIELDS`, `DISPLAY`, `status_label`, `status_dot_class` |
| `app/views/layouts/application.html.erb` | Authenticated shell |
| `app/views/layouts/auth.html.erb` | Login layout |
| `app/views/sessions/new.html.erb` | The login form |
| `app/views/shared/_login_header.html.erb` | Logo and heading above the login form |
| `app/views/shared/_alert.html.erb` | Toast alert (success/error), rendered from `flash[:notice]`/`flash[:alert]` |
| `app/javascript/controllers/toast_controller.js` | Fades the toast in, auto-dismisses it after 5s, handles manual close |
| `app/javascript/controllers/password_visibility_controller.js` | Show/hide toggle on password fields |
| `app/javascript/controllers/mobile_nav_controller.js` | Opens/closes the off-canvas sidebar below the `md` breakpoint |
| `app/views/shared/_admin_sidebar.html.erb` | Nav; off-canvas panel below `md` |
| `app/views/connections/index.html.erb` | The five service cards |
| `app/views/connections/_connection_card.html.erb` | One service's status and Edit link |
| `app/views/connections/edit.html.erb` | The credential form |
| `app/views/shared/_form_group.html.erb` | Shared field wrapper, incl. multiline support |
| `app/helpers/application_helper.rb` | `admin_nav_icon` |
| `app/controllers/dashboard_controller.rb` | Single `index` action; all computation lives in the presenter |
| `app/presenters/dashboard_presenter.rb` | Client counts, the cycle's report rows, elapsed/average timing, connection health |
| `app/helpers/dashboard_helper.rb` | Status badge classes/labels, `held_reason`, `duration_in_words` |
| `app/views/dashboard/index.html.erb` | The Dashboard page |
| `app/views/shared/_stat_card.html.erb` | The metric-card pattern, shared with the public report |
| `app/controllers/report_logs_controller.rb` | Single `index` action; month filter parsed and applied by the model |
| `app/views/report_logs/index.html.erb` | The Report Log page; reuses `DashboardHelper`'s status badges |
| `app/javascript/controllers/month_switcher_controller.js` | Also drives the Report Log's month filter, not just the public report |
| `test/controllers/connections_controller_test.rb` | Role gating, blank-means-unchanged, secrets never echoed |
| `test/controllers/sessions_controller_test.rb` | Login and logout |
| `test/controllers/dashboard_controller_test.rb` | Renders real data, shows a not-started client, shows the real held reason |
| `test/presenters/dashboard_presenter_test.rb` | Counts, progress percent, average generation time, elapsed |
| `test/controllers/report_logs_controller_test.rb` | Lists a ready report with a view link, hides the link when not ready, month filter |
| `test/models/monthly_report_test.rb` | `for_report_log` ordering/scoping, `parse_month_param` |
| `app/controllers/clients_controller.rb` | The 7 RESTful actions; search/status/pagination in `index`, tab selection in `show` |
| `app/controllers/concerns/finds_client.rb` | `set_client`, `client_params` (name/address/website/phone + nested `client_service_links_attributes`) |
| `app/queries/paginated_clients_query.rb` | Page/offset math and `total_count` for the index |
| `app/presenters/client_row_presenter.rb` | Index row: initials, enrollment tags, HubSpot sync label, delivery status |
| `app/models/client.rb` | `service_links_for_form`, `hubspot_link`, placeholder-name and name-validation logic |
| `app/models/client_service_link.rb` | HubSpot sync trigger and status-reset callbacks |
| `app/models/service.rb` | `Service::KEYS` — the five service keys iterated on the Data sources form |
| `app/models/agency_connection.rb` | `DISPLAY` — badge letter/colour reused for each Data sources row |
| `app/services/sync_client_from_hubspot.rb` | `record_attempt` — writes `last_synced_at`/`last_sync_error` after every sync attempt |
| `app/jobs/sync_hubspot_client_job.rb`, `app/jobs/enqueue_hubspot_sync_job.rb` | The immediate (per-save) and hourly (per-cycle) HubSpot sync paths — see [integrations](integrations.md) |
| `app/jobs/test_client_service_connection_job.rb`, `app/jobs/test_client_service_connections_job.rb` | The immediate (per-save) and daily (per-cycle) connection checks for every other linked service |
| `app/helpers/clients_helper.rb` | Status badge classes/labels for onboarding, reports, data sources, and HubSpot sync; `hubspot_sync_error_message`'s plain-language translation table |
| `app/views/clients/index.html.erb` | Search, status chips, the practice table, pagination |
| `app/views/clients/show.html.erb` | Hero banner (full-width) + tab nav + tab content (`max-w-4xl`) |
| `app/views/clients/_overview_tab.html.erb` | Latest report snapshot, current-month status, HubSpot sync status, report link |
| `app/views/clients/_reports_tab.html.erb` | Per-month generation/send status history |
| `app/views/clients/_keywords_tab.html.erb` | Latest report's keyword rankings, paginated |
| `app/views/clients/_sources_tab.html.erb` | Read-only Data sources summary; Edit links to the Edit practice form |
| `app/views/clients/_form.html.erb` | Shared Add/Edit form: practice details, Data sources, read-only Reporting panel |
| `app/views/clients/new.html.erb` | Thin wrapper around `_form` for `create` |
| `app/views/clients/edit.html.erb` | Thin wrapper around `_form` for `update` |
| `app/javascript/controllers/copy_controller.js` | Copy-to-clipboard for the report link and any other `data-controller="copy"` field |
| `app/javascript/controllers/client_menu_controller.js` | The per-row actions menu on the index (View / Edit / Offboard, or Recover / Delete permanently for an offboarded practice) |
| `app/controllers/clients/sync_services_controller.rb` | The **Sync services** action, which replaced the GHL-only Find GHL match — see [client-onboarding](client-onboarding.md) |
| `app/services/ghl_location_matcher.rb` | The domain-matching logic itself |
| `app/javascript/controllers/apply_suggestion_controller.js` | Click-to-fill the suggested location ID into the field above |
| `test/controllers/clients_controller_test.rb` | Search/filter/pagination, create/update incl. nested attributes, HubSpot sync enqueue, role gating, discard-not-delete |
| `test/models/client_test.rb` | Onboarding-status default, conditional name validation, placeholder name, `search`/`by_status` scopes |
| `test/models/client_service_link_test.rb` | Sync-enqueue conditions, sync-status reset on ID change |
| `test/helpers/clients_helper_test.rb` | Every status-label/dot-class/error-message branch |

### Data

| Model / table | What it holds here |
|---|---|
| `AdminUser` | `email`, `password_digest`, `role` (`admin` / `support`) |
| `AgencyConnection` | One row per service; `encrypted_credentials`, `credential_status` |
| `Service` | Lookup table the service column keys against |
| `MonthlyReport` | Read, not written, by the Dashboard and Report Log: `generation_status`, `attempt_count`, `generation_started_at`. See [report-generation](report-generation.md) |
| `SendLog` | Read for the `held` status and its `error_message`. See [monthly-report](monthly-report.md) |
| `Client` | `name`, `address`, `website_url`, `phone` (admin-editable); `onboarding_status`, `onboarded_at`, `ai_seo_enrolled` (HubSpot-owned, read-only on this form); `sitemap_url` (never set here — discovered from robots.txt during report generation) |
| `ClientServiceLink` | One row per `Service::KEYS` per client; `external_id` (admin-editable); `last_synced_at`, `last_sync_error` (written only by `SyncClientFromHubspot`, HubSpot's row only) |

Invariants:

- `AdminUser` email is unique, format-validated, and downcased before validation.
- Password minimum length 8, enforced only when a password is being set.
- `credential_status` uses `prefix: :credential` **because a bare `invalid` value would
  override Active Record's own `#invalid?`**.
- `encrypted_credentials` is `encrypts`ed.
- `clients.onboarding_status` defaults to `"pending"` at the DB level, so a manually-created
  client (no HubSpot ID yet) always has a valid enum value rather than `nil`.
- `Client#name` presence is validated **unless** a HubSpot-service `client_service_links`
  row has a present `external_id` — see Gotchas.
- `client_service_links` has a unique index on `(client_id, service)` — one row per service
  per client, enforced in the database, not only in Ruby.

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| Wrong email or password | "Incorrect email or password", 422 | Nothing |
| Not logged in | Redirect to login | Nothing |
| Support user attempts a write | Redirect with permission message | Nothing |
| Unknown service in the URL | Redirect to Connections, "Unknown service" | Nothing |
| Service with no configurable fields | Redirect, "isn't configurable yet" | Nothing |
| HubSpot sync fails (bad ID, no access, timeout, etc.) | Plain-language reason on the Overview tab, Edit form, and index row | `client_service_links.last_sync_error` |
| Client created/edited with no name and no HubSpot ID | 422, "Name can't be blank" | Nothing |
| GHL location match: no location's website matches | "No GHL location found matching this practice's website." | Nothing |
| GHL location match: GHL API call fails | Generic "Couldn't reach GoHighLevel…" alert | Nothing |

**No failed-login auditing of any kind.** Nothing records or limits repeated attempts.

**A HubSpot sync failure is not otherwise surfaced anywhere** — no email, no Dashboard
count, no entry in the "recent failures" view that doesn't exist yet (see
[report-generation](report-generation.md)'s equivalent gap). An admin has to open the
practice to see it.

### Gotchas

- **`Client#name` is conditionally required.** It's the one field this form doesn't always
  demand — skip it and the HubSpot sync fills it in. If you're debugging "why did this save
  with a blank-looking name", check `syncing_from_hubspot?` and the placeholder text
  ("Syncing from HubSpot…") before assuming the validation is broken.
- **There is no "sync now" endpoint.** Saving the form is the only trigger — a
  `ClientServiceLink` callback (`after_commit`), not a controller action. A prior version
  had a dedicated endpoint and button; it was removed as redundant once save-triggers-sync
  landed. Don't re-add a duplicate control without removing the auto-sync-on-save first.
- **Changing a HubSpot ID resets `last_synced_at`/`last_sync_error` before the new sync even
  runs.** If you're testing this in the console, seed those two columns with
  `update_columns` (not `update!`/`create!` alongside `external_id`) or the reset callback
  will immediately wipe what you just set — see `test/models/client_service_link_test.rb`
  for the pattern.
- **No background worker runs by default in dev.** `Procfile.dev` includes a `jobs: bin/jobs`
  line specifically so `bin/dev` starts one — without it, `SyncHubspotClientJob` (and every
  other queued job) sits enqueued forever and nothing looks like it's happening.
- **The Dashboard never queries adapters or triggers generation** — it only reads
  `MonthlyReport`/`SendLog`/`AgencyConnection` state that other code already wrote.
  "Generating" is real process state a run is in, not something the Dashboard causes.
- **A client with no report row for the cycle is still shown**, as "Not started" —
  `DashboardPresenter#report_rows` pairs every active client with its report, nil when
  there isn't one yet, specifically so a client the run hasn't picked up doesn't silently
  vanish from the table.
- **`elapsed`/`progress_percent`/`average_generation_time` assume one coherent run** — every
  report for the cycle created at roughly the same time by `EnqueueMonthlyReportsJob`. A
  manually-backfilled report from a different time will skew `elapsed` for the whole cycle.
- **`#update` merges rather than replaces.** A blank field preserves the stored value, so
  clearing a credential is not possible through the UI.
- **`status_label` treats "no configurable fields" as "Not available yet"**, which is why
  adding fields for a service changes its label as a side effect.
- **`DISPLAY[:badge_class]` holds a complete literal Tailwind class**, never assembled from
  a colour name, because Tailwind only compiles classes it can find literally in source.
- **These controllers keep private methods**, which CLAUDE.md's actions-only rule says to
  move into `app/controllers/concerns/`. They are the documented migration targets.
- **Login has no rate limiting**, and looking the user up before authenticating leaks which
  emails exist through response timing. Both are recorded in CLAUDE.md → Security.
- **The GHL suggestion button (`Find GHL match`) is not a `button_to`** — a nested `<form>`
  inside `_form.html.erb`'s main form is invalid HTML and silently breaks **Save practice**.
  It uses the `form=""` attribute instead. See
  [integration-ghl](integration-ghl.md#location-auto-match-by-domain).

### Not built yet

- **Managing tracked keywords** — still console-only (see [MSP-GUIDE](../MSP-GUIDE.md#tracked-keywords)); auto-discovered from SEMrush, so this is only for suppressing one.
- **Admin user management** — no UI to create, disable or reset an account.
- **Credential verification** — nothing ever sets `credential_status`, including on `ClientServiceLink` for the four non-HubSpot services.
- **No password reset, no MFA, no session expiry, no audit log.**

---

## Changing this feature

- **Never render a stored credential back to the browser.** The blank-field behaviour is a
  security property, and there is a test asserting the secret does not appear in the
  response body — keep it for any new credential surface.
- **Every mutating action needs `require_editor!`.** The test must prove `support` is
  blocked, not merely that `admin` is allowed.
- **`support` is read-only** and must stay so.
- **Never add a plaintext secret column.**
- **Never make `onboarding_status`, `onboarded_at`, or `ai_seo_enrolled` editable on the
  Clients form.** They are HubSpot's fields, confirmed with MSP (SOW #9) — a manual override
  would silently get overwritten by the next sync, which is worse than not offering it. If a
  real need to override HubSpot emerges, that's a product decision to raise, not a field to
  quietly unlock.
