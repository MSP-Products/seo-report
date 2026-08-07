# Brief for Claude Design — MSP internal admin

## Your role

You are designing the **internal admin surface** of an SEO reporting system for
**My Social Practice (MSP)**, a marketing agency serving dental practices. MSP staff use
it; their clients never see it.

The client-facing report is **out of scope** — it was specified by the client from three
reference prototypes and already ships. You are designing the screens MSP's own team needs
to run the system, which today do not exist.

---

## The product in one paragraph

Once a month, for each dental practice MSP works with, the system pulls data from five
external services, freezes it as a snapshot, and publishes a private web page the practice
opens from an emailed link. There are two surfaces: that public report, and an internal
admin panel. **The admin panel currently has exactly one working page** (API credentials).
Everything else MSP needs to do — adding a practice, connecting it to data sources,
generating a report, checking whether it worked — is a command a developer runs.

---

## What the statement of work requires

Section 8 of the SOW, *Admin / Internal Needs*, is the source of truth for this work:

> - Some way for MSP team to view send history / troubleshoot a given month's reports
>   (level of detail: TBD — could be as simple as a direct database query, or a lightweight
>   internal dashboard)
> - Clear error messages when something fails (e.g. an API call fails, a report can't
>   generate)
> - Notifications when an API key/token is expiring or has expired, so MSP can renew it
>   before reports break
> - Written instructions for MSP on how to add a new client to the reporting system, and how
>   to remove one

The last item is already delivered as `docs/MSP-GUIDE.md`. **The first three are what you
are designing for.**

Note the SOW deliberately leaves the level of ambition open. Part of what we want from you
is a recommendation on where the line sits between "lightweight" and "genuinely useful".

---

## Read this first

All paths relative to the repository root.

**Understand the system:**
- `docs/README.md` — what the system is, and an honest statement of what is and isn't built
- `docs/MSP-GUIDE.md` — **the most important file for this brief.** Every task under
  "Needs a developer" is a screen that does not exist. Read it as a requirements list
- `docs/features/report-generation.md` — what generation does, and every way it degrades
- `docs/features/admin-panel.md` — the one page that exists today, and its "Not built yet"
- `docs/reference/data-model.md` — every table and column you can put on a screen
- `docs/reference/jobs-and-schedules.md` — what runs when, and what silently doesn't

**The existing visual precedent — match this:**
- `app/views/connections/index.html.erb` and `_connection_card.html.erb`
- `app/views/connections/edit.html.erb`
- `app/views/shared/_admin_sidebar.html.erb`, `_form_group.html.erb`, `_alert.html.erb`
- `app/assets/tailwind/application.css` — the design tokens

---

## Our design system — extend it, don't replace it

The admin panel and the public report already share one visual language. New pages must sit
alongside the Connections page without a seam.

**Tokens** (`app/assets/tailwind/application.css`):

| Token | Value | Use |
|---|---|---|
| `--color-teal-primary` | `#0d9488` | Primary actions, active nav, brand mark |
| `--color-teal-dark` | `#0f766e` | Links, hover, icon glyphs |
| `--color-cyan-primary` | `#06b6d4` | Gradient partner to teal |
| `--color-cyan-light` | `#22d3ee` | Gradient extension |

**Supporting palette, used consistently:** **slate** for all neutrals — `slate-50` page
wash, `slate-900` headings, `slate-700`/`slate-500` body and muted, `slate-200` borders.
**emerald** for success and positive movement. **amber** for warning. **red** for failure.

**Shape and type:** Inter. Cards are `rounded-2xl border border-slate-200 bg-white p-5
shadow-sm`. Inner tiles `rounded-xl`, controls `rounded-lg`. Page titles
`text-2xl font-semibold tracking-tight text-slate-900` with a `text-sm text-slate-500`
subtitle beneath.

**Existing components to reuse rather than reinvent:** the service card with its status dot
and label, the form group (which supports a password toggle and a textarea), the flash
alert, and the fixed 60-unit sidebar with its active-item treatment.

**Icons** come from a fixed Lucide-matched set rendered by a helper. Do not design anything
that needs an icon outside a small, nameable set — and list any new icons you rely on.

---

## The screens

### 1. Dashboard — the SOW's "lightweight internal dashboard"

This is the priority. It replaces the sidebar's current stub.

**The question it must answer in one glance: did this month's reports work, and what needs
me?** Today that answer exists only in a database table nobody reads, and **nothing alerts
anyone when a report fails or was never generated at all.**

Real states it must cover:

- A practice whose report **generated cleanly**
- One that **generated with warnings** — succeeded, but a section is missing because an API
  failed. This is the common case and the easiest to miss, because the status is still
  "success"
- One that **failed outright** — a bug, with an error to show
- One where **generation was never run** — no record exists. Silence, and the hardest state
  to represent
- One **not yet sent**, and one **already sent** (a timestamp exists to prevent duplicates)
- A practice **onboarded mid-month**, whose first report is a different shape

It should also surface, per the SOW:

- **Credential health** — which API keys are expiring or expired, *before* reports break.
  The data model has fields for this that nothing currently writes
- **Clear errors** — a failed run stores a summary and a full log. Design how much is shown
  inline versus on demand
- **Website scan health** — a nightly job records per-practice success or failure and is
  surfaced nowhere

Design decisions we want your view on: is the primary axis *this month across all
practices*, or *one practice across time*? What earns a place on the landing view versus a
drill-in? How do you show "never ran" alongside "ran and failed" without conflating them?

### 2. Clients — practice management

**Not strictly SOW-mandated** — §8 accepts written instructions for adding and removing a
practice, which exist. But every task in MSP-GUIDE's "Needs a developer" list lives here,
and until it exists MSP cannot operate the system without a developer. **Treat it as
strongly recommended and tell us if you disagree.**

A practice needs:

- **Its own details** — name, address, website, onboarding status, whether they're enrolled
  in AI SEO. Note these are **overwritten from HubSpot on every report run**, so the screen
  must not imply they are editable here in a lasting way. Designing that honestly is part
  of the problem
- **A connection per external service** (five of them), each needing an identifier that
  lives in that service. The identifiers are inconsistent and easy to get wrong — one
  requires a compound ID from a URL, another requires the practice to grant access to a
  robot account. **The screen should prevent the mistakes, not just collect the values**
- **Tracked keywords** — a list, added and retired, each with a search-intent marker
- **Its reports** — every month generated, each with a private link to copy, generation
  status, and whether it was sent
- **Website scan status** — how pages are being discovered, and whether it is working

One rule with teeth: **a practice's link to the appointment-scheduler service is itself the
record of whether they use that product.** Connecting it changes what their report claims
about them. That is not ordinary configuration and should not look like it.

---

## Hard constraints

1. **Extend the existing design system.** Same tokens, same card and form vocabulary, same
   sidebar. A new page must not look like a different product.
2. **Two roles.** `admin` can change things; `support` can view everything and change
   nothing. Design the read-only state — do not simply hide controls without explanation.
3. **Never display a stored credential.** Existing values render blank, always, and blank
   means unchanged. This is a security property with a test behind it. Any new credential
   input must behave the same way.
4. **Report links are sensitive.** The link is the only thing protecting a practice's
   report. Treat copying and displaying it with care.
5. **No dark mode** today. Do not introduce one.
6. **No new icon library.** Icons come from one small helper-rendered set.
7. **Server-rendered Rails with light Hotwire.** No client-side framework, no build step.
   Everything must work as plain HTML with progressive enhancement; assume no
   JavaScript-only interactions.
8. **Desktop-first, but must not break on a tablet.** This is an internal tool used at a
   desk, unlike the report, which is read on phones.
9. **Design the empty and failure states, not just the happy path.** A brand-new install
   has no practices, no reports, and no credentials. That is the first thing MSP will see.

---

## Deliverables

**These designs get implemented directly, so the output format matters as much as the
design.** We build in Rails ERB with Tailwind v4 utility classes — the same stack the
prototypes should be written in, so markup lifts across with minimal translation.

1. **Self-contained HTML prototypes, styled with Tailwind utility classes**, one file per
   screen. Not images, not a design-tool export. Use the token names in our config
   (`bg-teal-primary`, `text-teal-dark`, `text-cyan-primary`) and standard Tailwind classes
   for everything else, so a developer can lift the markup into an ERB template and change
   only the dynamic values.
   - Static markup is fine — no framework, no build step.
   - Where a screen has states, show them **all**, laid out on the page and labelled, rather
     than hidden behind interactivity we cannot inspect.
2. **Every state from the sections above**, including empty, degraded, and failure. A
   populated happy path alone is not implementable — those are the states we will get wrong.
3. **A component spec** for anything new: anatomy, the existing tokens used, states
   (default, hover, active, disabled, and read-only for `support`), and how it composes with
   what already exists. Say explicitly which existing components you reused and which are
   genuinely new — a new component is a cost, so justify each one.
4. **Responsive behaviour** at desktop and tablet. Say what reflows, what collapses, and
   what is allowed to scroll horizontally.
5. **A written rationale** — the information hierarchy you chose and why, what you left off
   the landing view, and where you think the SOW's "lightweight" line should sit.
6. **A recommendation on the Clients screen** — build it, or is the written guide genuinely
   enough for now? We would rather hear "not yet, and here's why" than get a screen nobody
   needs.
7. **Anything you would add that we have not asked for**, if it follows from the SOW's
   intent. §8's underlying goal is that MSP finds out about a problem *before* a client
   does.

**Do not invent data.** Every number, status and label must correspond to something in
`docs/reference/data-model.md`. If a screen needs a value the system does not currently
store, that is a legitimate finding — call it out as a required backend change in the
rationale rather than quietly drawing it.

---

## Acceptance

- Both screens exist, cover the listed states, and are visibly the same product as the
  Connections page.
- Every element traces to an existing token or component, or is flagged as an extension
  with a reason.
- Empty, degraded, and failure states are designed, not implied.
- The `support` read-only state is designed.
- The rationale engages with the actual constraints — the HubSpot overwrite, the
  scheduler-link meaning, the never-ran state — rather than treating this as a generic admin
  panel.

---

## Copy conventions

Sentence case throughout. No em-dashes or smart punctuation in interface strings. Verb-first
for actions. Say "practice", not "client", in anything MSP-facing — "client" is ambiguous
between the practice and MSP itself.
