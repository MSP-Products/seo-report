---
title: Admin panel
slug: admin-panel
status: partial
last_verified: 2026-08-02
related: [integrations, report-generation, dashboard-and-clients]
---

# Admin panel

> **Status:** partial — login, Connections, Dashboard, and Clients all work ·
> **Last verified:** 2026-08-02
>
> The internal, logged-in side of the system: who can get in, and the one page that
> currently does anything.

---

## For everyone

### Purpose

MSP staff need somewhere to manage the API credentials the reports are built from, without
a developer editing a config file. The admin panel is that place.

It is deliberately small. Today it manages agency-wide credentials and nothing else —
every other operational task is still a command. See [MSP-GUIDE](../MSP-GUIDE.md).

### Who uses it

**MSP staff only.** Practices never see it. Two roles:

| Role | Can |
|---|---|
| **admin** | View everything and change API credentials |
| **support** | View everything, change nothing |

### How it behaves

1. Go to `/login`, enter email and password.
2. Landing page is **Connections**, listing all five services with a status.
3. An admin clicks **Edit** on a service, enters the credential, and saves.
4. A support user clicking Edit is redirected with a permission message.
5. Log out from the sidebar.

**There is no sign-up page and no password reset.** Accounts are created by a developer.

**Credential fields always render blank**, even when a value is stored — a saved secret can
never be read back out of the page. **Leaving a field blank keeps the existing value**; you
only type into it to replace one.

The sidebar also shows **Dashboard** and **Clients**, which now lead to their own
pages — see [Dashboard and clients](dashboard-and-clients.md).

### When data is missing

| Situation | What's shown |
|---|---|
| A service has no credential saved | "Not configured", grey dot |
| A credential is saved but never verified | "Unverified" |
| A service has no configurable fields | "Not available yet", and Edit is hidden |

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
| `app/models/agency_connection.rb` | `CREDENTIAL_FIELDS`, `DISPLAY`, `status_label`, `status_dot_class` |
| `app/views/layouts/application.html.erb` | Authenticated shell |
| `app/views/layouts/auth.html.erb` | Login layout |
| `app/views/sessions/new.html.erb` | The login form |
| `app/views/shared/_login_header.html.erb` | Logo and heading above the login form |
| `app/views/shared/_alert.html.erb` | Flash notice and error banner |
| `app/javascript/controllers/password_visibility_controller.js` | Show/hide toggle on password fields |
| `app/views/shared/_admin_sidebar.html.erb` | Nav, incl. links to Dashboard and Clients — see [dashboard-and-clients.md](dashboard-and-clients.md) |
| `app/views/connections/index.html.erb` | The five service cards |
| `app/views/connections/_connection_card.html.erb` | One service's status and Edit link |
| `app/views/connections/edit.html.erb` | The credential form |
| `app/views/shared/_form_group.html.erb` | Shared field wrapper, incl. multiline support |
| `app/helpers/application_helper.rb` | `admin_nav_icon` |
| `test/controllers/connections_controller_test.rb` | Role gating, blank-means-unchanged, secrets never echoed |
| `test/controllers/sessions_controller_test.rb` | Login and logout |

### Data

| Model / table | What it holds here |
|---|---|
| `AdminUser` | `email`, `password_digest`, `role` (`admin` / `support`) |
| `AgencyConnection` | One row per service; `encrypted_credentials`, `credential_status` |
| `Service` | Lookup table the service column keys against |

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