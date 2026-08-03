---
title: Dashboard and clients
slug: dashboard-and-clients
status: partial
last_verified: 2026-08-03
related: [admin-panel, report-generation]
---

# Dashboard and clients

> **Status:** partial — both pages render with static, hardcoded data; nothing here reads
> from the database yet · **Last verified:** 2026-08-03
>
> The two admin-panel pages that give MSP staff an overview of report activity (Dashboard)
> and a roster of practices (Clients), replacing the placeholders that used to redirect to
> Connections.

---

## For everyone

### Purpose

MSP staff need a home page that shows what's happening across all practices — reports
sent, pending, failed — without opening each practice individually. They also need a
single list of every practice the agency manages. Dashboard and Clients are that overview
and that list.

### Who uses it

Same roles as the rest of the [admin panel](admin-panel.md): **admin** and **support**.
Both pages are currently read-only for both roles — there is no write action yet, so the
usual admin/support distinction doesn't apply here.

### How it behaves

1. After logging in, click **Dashboard** or **Clients** in the sidebar.
2. **Dashboard** shows: a short client list, a connection-status summary for the external
   services, and send-progress counts (sent / ready / pending / failed) as both numbers
   and percentages of an expected total.
3. **Clients** shows the full roster: name, address, website, onboarding state, last
   report period, generation status, and send status for each practice.
4. Clicking a client (once wired up) is meant to lead to a detail view with that client's
   report history — **the `show` action and its view exist, but nothing links to them
   yet.**
5. **New** has a route and an empty action, but no form — clicking it does nothing useful
   today.

### When data is missing

**Not applicable in the way it usually is here.** Both pages currently show the *same*
hardcoded data to everyone, every time — there is no real "missing data" state to
describe, because nothing is being fetched from a live source yet. See Not built yet.

### FAQ

**Q: Why do all the numbers look the same every time I visit?**
A: Because they are. Dashboard and Clients are still wired to static Ruby arrays, not the
database. Nothing you do elsewhere in the app changes what these pages show.

**Q: I clicked a client name and nothing happened.**
A: Expected for now — the roster doesn't link to the detail page yet, even though the
detail page itself exists.

**Q: Can I add a new client here?**
A: Not yet. The **New** link exists in name only.

---

## For developers

### How it works

Both controllers are intentionally simple and currently free of any model or database
access — they exist to let the views and layout be built and reviewed before the real
data layer is wired in.

`DashboardController#index` builds four instance variables from inline Ruby, not from
`ClientsController::CLIENTS`'s full set: `@clients` is just `CLIENTS.first(5)` (borrowed
from `ClientsController`, not its own source of truth), `@connections` is a hand-written
array of service/status pairs, and `@progress_counts` / `@progress_percents` are derived
from a hardcoded `counts` hash against a hardcoded `@total_expected`.

`ClientsController` owns two frozen constants, `CLIENTS` and `REPORTS`, that stand in for
what will eventually be `Client` and `MonthlyReport` records. `#index` lists `CLIENTS`.
`#show` finds one by `params[:id]` (falling back to the first client if the id doesn't
match) and always attaches the same `REPORTS` array regardless of which client was
requested — the per-client report history isn't real yet. `#new` renders an empty view.
`#create` redirects straight back to `clients_path` without persisting anything.

The sidebar (`app/views/shared/_sidebar.html.erb`, shared with the rest of the admin
panel) links to `dashboard_path` and `clients_path`, both added to `config/routes.rb`
alongside the existing `connections` resource.

### Key files

| Path | Role in this feature |
|---|---|
| `app/controllers/dashboard_controller.rb` | Builds the overview page's static client list, connection statuses, and send-progress counts |
| `app/controllers/clients_controller.rb` | Owns the `CLIENTS` and `REPORTS` placeholder data; `index`, `show`, `new`, `create` |
| `app/views/dashboard/index.html.erb` | Dashboard page markup |
| `app/views/clients/index.html.erb` | Client roster table |
| `app/views/clients/show.html.erb` | Single client's report history (not yet linked from the roster) |
| `app/views/clients/new.html.erb` | Placeholder new-client view |
| `app/views/shared/_sidebar.html.erb` | Nav, now pointing Dashboard and Clients at real pages instead of redirecting to Connections |
| `app/assets/stylesheets/dashboard.css` | Dashboard page styling |
| `app/assets/stylesheets/clients.css` | Clients page styling |
| `config/routes.rb` | `get "dashboard"` and `resources :clients` |

### Data

| Model / table | What it holds here |
|---|---|
| *(none)* | Both pages read from in-memory Ruby constants (`ClientsController::CLIENTS`, `ClientsController::REPORTS`), not from any table |

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| Any client id in the URL, valid or not | The first client's data (silent fallback in `#show`) | Nothing |
| Visiting `/clients/new` | An empty form-less page | Nothing |
| Submitting from `/clients/new` | Redirect to the roster, nothing saved | Nothing |

There is no error state to fail into yet, since nothing here talks to a database or an
external service.

### Gotchas

- **`DashboardController#index` does not reuse `ClientsController::REPORTS` or the full
  `CLIENTS` list** — its numbers are a separate hardcoded hash. Changing one does not
  change the other; don't assume they're derived from the same source.
- **`ClientsController#show` always returns the same `REPORTS`**, regardless of which
  client id was requested. Don't mistake this for a real per-client history when wiring up
  a link to it.
- **The roster in `clients/index.html.erb` does not link to `clients/show.html.erb`.** The
  show page and its route both work if visited directly, but nothing in the UI reaches it.
- **`ClientsController::CLIENTS` and `REPORTS` are frozen, module-level constants**,
  the same pattern `AgencyConnection` avoids by living in a real table — expect these to
  be replaced by `Client` and `MonthlyReport` models rather than extended in place.

### Not built yet

- **Real data.** Both pages are static; nothing reads from `Client`, `MonthlyReport`, or
  any other table.
- **A link from the client roster to the client detail page.**
- **A working "New client" form.** The route and action exist; the form does not.
- **Per-client report history.** `#show` cannot yet distinguish one client's reports from
  another's.
- **Any write path at all.** `#create` redirects without persisting.

---

## Changing this feature

- **Don't build real data access by editing the `CLIENTS` / `REPORTS` constants in
  place.** They exist to unblock the view layer; the intended path is replacing them with
  real models, not growing them.
- **When the roster starts linking to the detail page, `#show`'s fallback-to-first-client
  behaviour needs to go** — silently substituting a different client's data would then be
  a real bug, not a placeholder.
- **Keep `DashboardController`'s numbers and `ClientsController`'s data reconciled or
  explicitly separate on purpose** — right now they can silently drift and nothing would
  notice.