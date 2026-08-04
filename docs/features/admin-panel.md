---
title: Admin panel
slug: admin-panel
status: partial
last_verified: 2026-08-03
related: [integrations, report-generation]
---

# Admin panel

> **Status:** partial — login, Dashboard, and Connections work; Clients is still a stub ·
> **Last verified:** 2026-08-03
>
> The internal, logged-in side of the system: who can get in, and what they see once
> they're in.

---

## For everyone

### Purpose

MSP staff need somewhere to see whether this cycle's reports are generating, and to manage
the API credentials reports are built from, without a developer editing a config file or
running a console command. The admin panel is that place.

It is deliberately small. Today it shows the current reporting cycle's status and manages
agency-wide credentials — every other operational task is still a command. See
[MSP-GUIDE](../MSP-GUIDE.md).

### Who uses it

**MSP staff only.** Practices never see it. Two roles:

| Role | Can |
|---|---|
| **admin** | View everything and change API credentials |
| **support** | View everything, change nothing |

### How it behaves

1. Go to `/login`, enter email and password.
2. Landing page is **Dashboard** — this cycle's client counts, generation progress, and
   per-service connection health, all real data.
3. **Report Log** lists every generated report across every practice and month, filterable
   by month, with a link to view each ready report.
4. **Connections** lists all five services with a status; an admin clicks **Edit**, enters
   the credential, and saves.
5. A support user clicking Edit is redirected with a permission message.
6. Log out from the sidebar.

**There is no sign-up page and no password reset.** Accounts are created by a developer.

**Credential fields always render blank**, even when a value is stored — a saved secret can
never be read back out of the page. **Leaving a field blank keeps the existing value**; you
only type into it to replace one.

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

The sidebar also shows **Clients**, still a stub that routes back to Connections so nothing
404s. It is not built.

### When data is missing

| Situation | What's shown |
|---|---|
| A service has no credential saved | "Not configured", grey dot |
| A credential is saved but never verified | "Unverified" |
| A service has no configurable fields | "Not available yet", and Edit is hidden |
| An active client has no report row for the cycle yet | Shown on the Dashboard as "Not started", never omitted |
| A report is ready but hasn't been emailed | "Not sent" — there is no mailer yet, so this is the default, not a failure |

**The health labels — Active, Expiring soon, Expired, Needs attention — are never set
automatically.** Nothing tests a credential and records its state, so they are decorative
today. The reliable check is to generate a report and read its warnings.

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
| `app/views/shared/_alert.html.erb` | Flash notice and error banner |
| `app/javascript/controllers/password_visibility_controller.js` | Show/hide toggle on password fields |
| `app/javascript/controllers/mobile_nav_controller.js` | Opens/closes the off-canvas sidebar below the `md` breakpoint |
| `app/views/shared/_admin_sidebar.html.erb` | Nav, incl. the Clients stub; off-canvas panel below `md` |
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

### Data

| Model / table | What it holds here |
|---|---|
| `AdminUser` | `email`, `password_digest`, `role` (`admin` / `support`) |
| `AgencyConnection` | One row per service; `encrypted_credentials`, `credential_status` |
| `Service` | Lookup table the service column keys against |
| `MonthlyReport` | Read, not written, by the Dashboard and Report Log: `generation_status`, `attempt_count`, `generation_started_at`. See [report-generation](report-generation.md) |
| `SendLog` | Read for the `held` status and its `error_message`. See [monthly-report](monthly-report.md) |

Invariants:

- `AdminUser` email is unique, format-validated, and downcased before validation.
- Password minimum length 8, enforced only when a password is being set.
- `credential_status` uses `prefix: :credential` **because a bare `invalid` value would
  override Active Record's own `#invalid?`**.
- `encrypted_credentials` is `encrypts`ed.

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| Wrong email or password | "Incorrect email or password", 422 | Nothing |
| Not logged in | Redirect to login | Nothing |
| Support user attempts a write | Redirect with permission message | Nothing |
| Unknown service in the URL | Redirect to Connections, "Unknown service" | Nothing |
| Service with no configurable fields | Redirect, "isn't configurable yet" | Nothing |

**No failed-login auditing of any kind.** Nothing records or limits repeated attempts.

### Gotchas

- **Clients deliberately routes to Connections.** It is a placeholder, not a broken link —
  don't "fix" it, build it.
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

### Not built yet

- **Clients** — no UI to add a practice, set per-service IDs, or manage keywords. All
  console or rake today.
- **Admin user management** — no UI to create, disable or reset an account.
- **Credential verification** — nothing ever sets `credential_status`.
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
