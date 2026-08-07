# MSP guide

How to run the SEO reporting system. Written for MSP staff, organised by the task you're
trying to do.

> **Read this first.** The admin panel has **three working pages** today: Dashboard,
> Connections, and Clients. Adding a practice and connecting it to a data source are now
> done from Clients — see below. Getting a practice's report link and troubleshooting one
> client's history are also done from Clients now (its Overview and Reports tabs). Tracked
> keywords and Google Analytics setup still need a developer or a source-system change;
> this guide says so and gives the exact command where that's the case.
>
> **Generating a report is the one exception** — it now runs automatically every 1st of
> the month. A developer is only needed to generate one on demand (a backfill, a retry
> outside the schedule).

---

## Contents

- [What the system does](#what-the-system-does)
- [Logging in](#logging-in)
- [Who can do what](#who-can-do-what)
- **In the admin panel**
  - [Add or update an API credential](#add-or-update-an-api-credential)
  - [Check whether a connection is healthy](#check-whether-a-connection-is-healthy)
  - [Check this cycle's status](#check-this-cycles-status)
  - [Add a new practice](#add-a-new-practice)
  - [Connect a practice to the data sources](#connect-a-practice-to-the-data-sources)
  - [Offboard, recover, or delete a practice](#offboard-recover-or-delete-a-practice)
- **Needs a developer**
  - [Set up Google Analytics for a practice](#set-up-google-analytics-for-a-practice)
  - [Tracked keywords](#tracked-keywords)
  - [Generate a report](#generate-a-report)
  - [Get a practice's report link](#get-a-practices-report-link)
  - [Check whether a report worked](#check-whether-a-report-worked)
  - [Re-run a failed report](#re-run-a-failed-report)
- [Where each ID comes from](#where-each-id-comes-from)
- [What a practice sees when data is missing](#what-a-practice-sees-when-data-is-missing)
- [Troubleshooting](#troubleshooting)

---

## What the system does

Once a month, for each practice, the system collects data from five external services,
saves a permanent snapshot of it, and publishes a private web page the practice can open.

```
HubSpot ─┐
GHL ─────┤
Yext ────┼──▶  Report generation  ──▶  Saved snapshot  ──▶  /reports/<link>
SEMrush ─┤        (per practice,          (frozen,            (what the
GA4 ─────┘         per month)              never edited)       practice opens)
```

Three things worth knowing before anything else:

1. **Reports only cover completed months.** There is no such thing as a report for the
   current month. Attempting one is refused.
2. **Reports are frozen.** Once generated, a report is a record of what was true then. It
   is not recalculated later, even if the underlying data changes.
3. **A missing data source doesn't break a report.** The affected section shows a
   placeholder and everything else renders normally.

---

## Logging in

Go to `/login` and enter your email and password.

**There is no sign-up page and no "forgot password" link.** Admin accounts are created by
a developer, via a rake task rather than a raw console command — nothing sensitive is ever
committed, since the values come from `ENV`:

```bash
ADMIN_EMAIL="someone@mysocialpractice.com" ADMIN_PASSWORD="a-long-unique-password" ADMIN_ROLE=admin bin/rails admin_users:create
```

On Railway: prefix the same command with `railway run`, or run it from the service's Shell
tab in the dashboard. `ADMIN_ROLE` defaults to `admin` if omitted (the other option is
`support`, view-only).

Password must be at least 8 characters. To reset one, a developer sets a new password on
the account via the Rails console the same way as before:
`AdminUser.find_by!(email: "...").update!(password: "...")`.

---

## Who can do what

Two roles:

| Role | Can |
|---|---|
| **admin** | View everything, and change API credentials |
| **support** | View everything, change nothing |

A support user who opens an edit page is redirected with a permission message. Neither
role can see a practice's report link from the admin panel yet — that needs a developer.

---

## Add or update an API credential

**This is the one task fully supported in the admin panel.** These are agency-wide keys:
one credential that works for every practice.

1. Log in as an **admin**.
2. Go to **Connections** (the landing page after login).
3. Find the service and click **Edit**.
4. Paste the new value and save.

**Existing values are never shown.** The field is always blank, even when a credential is
already saved — that's deliberate, so a key can't be read back out of the page. **Leaving
a field blank keeps the existing value.** You only ever type into it to replace one.

What each service needs:

| Service | Field(s) |
|---|---|
| HubSpot | Access Token |
| Yext | API Key |
| SEMrush | API Key |
| Google Analytics | Client Email **and** Private Key (see [GA4 setup](#set-up-google-analytics-for-a-practice)) |

**GoHighLevel is the one exception — there's no field to paste.** Click **Connect to
GoHighLevel** instead and authorize once through GHL's own consent screen; from then on the
Connections page shows a live status (Active / Expiring soon / Expired) that refreshes
itself automatically, and reconnecting only comes up again if the grant is revoked on GHL's
side.

---

## Check whether a connection is healthy

The Connections page shows a coloured dot and a label per service:

| Label | Means |
|---|---|
| Active | Credential saved and verified |
| Expiring soon | Working, but needs replacing shortly |
| Expired / Needs attention | Not working — reports using this service will show placeholders |
| Unverified | Saved, but not yet checked against the live service |
| Not configured | No credential saved |

**For every service except GoHighLevel, these statuses are not yet updated
automatically.** Nothing currently sets them by testing the credential, so treat them as a
note rather than live monitoring for HubSpot, Yext, SEMrush, and Google Analytics. **GHL is
the exception:** its status is live — set on every connect and refreshed hourly in the
background — because the OAuth connection genuinely is verified each time it renews. For
everything else, the reliable way to know a service is working is to [generate a report and
read the warnings](#check-whether-a-report-worked).

---

## Check this cycle's status

The Dashboard — the page you land on after logging in — shows the last completed month's
reporting cycle at a glance:

- **Active clients**, and how many are still pending onboarding.
- **Reports generated** this cycle against the total number of active clients, with a
  Running/Completed badge and a failed count when there is one.
- **Reports sent** against reports held, with the real reason a hold happened (e.g.
  "HubSpot token rejected") shown next to the client it affects.
- **Average generation time** per report, for this cycle.
- While generation is running: which client is currently being processed, a progress bar,
  and when the run started.
- **A per-client table** for the cycle — including any active client the run hasn't picked
  up yet, shown as "Not started" rather than left off the list.
- **Per-service connection health**, the same data as the Connections page.

This is real data, not a summary someone maintains — if a client is missing a report, or a
send is held, the Dashboard is showing what's actually in the database right now.

---

## Add a new practice

**Go to Clients → Add client → pick your entry point:**

### Entry point 1: Import from HubSpot (recommended)

1. Click **Add client** dropdown → **Import from HubSpot**
2. Search for the practice by name or domain
3. Pick it from the results (HubSpot company name shown with domain)
4. Click **"Use this"** → opens the New form with:
   - Practice name pre-filled from HubSpot
   - **HubSpot service ID pre-filled** (but NOT synced yet — just pre-filled)
5. (Optional) Fill in remaining details: website, phone, address
6. Click **"Add client"** → **This is when the sync happens**:
   - Creates the practice
   - Enqueues `SyncHubspotClientJob` immediately
   - Shows "Syncing…" on the Edit page while it fetches onboarding_status, onboarded_at, and AI SEO enrollment from HubSpot

HubSpot's Search API returns real-time results, so this is the fastest way to onboard a new practice — no typing.

### Entry point 2: Add manually

1. Click **Add client** dropdown → **Add manually**
2. Type practice name (required), website, phone, address (optional)
3. Save → practice created as **Pending** with a blank HubSpot ID field

This path is for practices not yet in HubSpot, or ones where you know the other service IDs but need to set up HubSpot later.

### Both paths: HubSpot sync happens immediately on save

Once you save (whichever entry path you took), if a HubSpot company ID is present, `SyncHubspotClientJob` enqueues immediately:

1. Fetches: Company name, Address, Website, Active checkbox, GMB SEO Start Date, Services Purchased multi-select
2. Updates the practice record with name/address/website if they came from HubSpot
3. Maps HubSpot's **Active** checkbox → **Onboarding status** (`Active` if checked, `Offboarded` if unchecked)
4. Maps **GMB SEO Start Date** → **Onboarded on** date
5. Maps **Services Purchased** → **AI SEO enrolled** (true if the multi-select includes the exact text **"AI SEO"**)
6. Edit form shows **green dot** + **"Synced *n* ago"** once complete

**A practice cannot reach Active onboarding status unless this HubSpot sync succeeds.** If the HubSpot "Active" checkbox was never set, the sync will pull "Offboarded" — check HubSpot directly before assuming the sync is broken.

**Re-syncing happens automatically:** Once a HubSpot ID is linked, `EnqueueHubspotSyncJob` runs daily and re-syncs the practice. Any changes to the HubSpot record flow through to the system automatically (within 24 hours, or immediately if you re-sync by hand on the Edit form).

**`website_url` must be the canonical domain** — it's used to find the practice's sitemap and to match keywords in SEMrush. If the practice is at `www.example.com/dental` , save just `https://example.com` so domain matching works across all services.

---

## Connect a practice to the data sources

**Go to the practice's Edit page.** The Data sources section has five services, and you have
two ways to fill them:

### Option A: Auto-match by domain (recommended for new practices)

**Click the "Sync services" button** (appears after you save the practice):

1. System checks GoHighLevel, Yext, and SEMrush simultaneously for domain matches
2. Each service shows an animated spinner with a countdown timer (estimated from real past checks)
3. As each completes (usually 2–3 seconds per service):
   - **Match found:** Shows company name, domain, and ID in a card. Click **"Use this"** to fill the field, or **"×"** to dismiss it
   - **No match found:** "No match found matching this practice's website."
   - **API error:** "Couldn't reach this service — try again in a moment."
4. Click **"Save practice"** to persist all filled IDs

**The timer is real:** It's the average from your last 3–4 checks of that same service, so it gets more accurate as you add more practices.

**Unsaved changes warning:** If you navigate away during editing, the browser warns you (you can still click back).

### Option B: Enter IDs by hand

Skip the Sync services button and paste IDs directly:

1. Find the ID (see [where each ID comes from](#where-each-id-comes-from))
2. Paste into the field
3. **Save practice**
4. Status dots show: Not linked / Linked (or for HubSpot, Syncing / Synced / Sync failed)

### HubSpot-specific behavior

HubSpot is the first field — the mandatory, single source of truth. Once you link it, all five services behave differently:
- **Must have HubSpot ID to reach Active status** (the onboarding status, date, and AI SEO enrollment come from there, nowhere else)
- Links with a **green dot + "Synced *n* ago"** after the first sync
- Re-syncs automatically every day
- If sync fails, shows **red dot + error reason** — click to see what went wrong

For GoHighLevel specifically,
**Find GHL match** under that row and the system checks every sub-account in the agency's
connected GHL account for one whose own website matches this practice's — if it finds one,
it shows the match (name, website, location ID) for you to review. Nothing is linked yet at
that point; you still need to click **Save practice** to actually confirm it, same as if
you'd typed the ID in yourself. If nothing comes back ("No GHL location found matching this
practice's website"), the practice either isn't a GHL sub-account under this agency yet, or
its website in GHL doesn't exactly match what's on file here — type the ID in by hand if you
have it from elsewhere.

**Changing a HubSpot ID re-syncs immediately** and clears whatever the previous ID's sync
found, so the status briefly shows "Syncing…" again rather than a stale result from the ID
you just replaced.

The old rake task still works for bulk-seeding a practice from environment variables in one
shot (useful when standing up several practices from a script), but the Edit practice page
is the normal path now:

```bash
REAL_CLIENT_NAME="Woodside Dental Care" \
HUBSPOT_ACCESS_TOKEN="..." HUBSPOT_COMPANY_ID="..." \
YEXT_API_KEY="..." YEXT_ENTITY_ID="..." \
SEMRUSH_API_KEY="..." SEMRUSH_PROJECT_ID="30632499_5220001" \
GA4_PROPERTY_ID="367543547" \
bin/rails reports:seed_real_client
```

Any service whose variables are missing is skipped and reported as such. A practice with
no link for a service simply has that section unavailable in their report — same as leaving
a field blank on the Edit page.

**GoHighLevel is special:** whether a GHL link exists *is* the "does this practice use our
appointment scheduler" signal. No link means appointments and revenue show `?`, and the
system never calls GHL at all for that practice. This is shown on the Edit page's Reporting
section as "Online scheduler — Connected / Not connected".

---

## Offboard, recover, or delete a practice

When a practice ends their engagement you **offboard** them. That hides them from the working
client list and stops their reports, but keeps every past report intact — so it is safe, and
reversible.

### Offboard a practice

1. **Clients** → find the practice
2. Click the **⋯** actions menu on its row → **Offboard**
   (on a phone, the archive icon in the same place)
3. Confirm

They move to the **Offboarded** tab, disappear from **Active**, and stop being picked up when
reports are generated. Their own page still opens, showing an "archived" notice and their full
report history.

### Recover a practice

1. **Clients** → the **Offboarded** tab
2. Find the practice → **⋯** → **Recover**
3. Read the warning, then confirm

The practice comes back as **Pending**, not Active. That is deliberate: only a successful
HubSpot sync is allowed to make a practice Active.

> **The warning matters.** HubSpot is the source of truth for whether a practice is active, and
> it re-syncs about once an hour. **If the practice is still marked offboarded in HubSpot, that
> sync will offboard them again** — your change here will look like it silently undid itself.
> **Fix HubSpot first, then recover here.**

### Delete a practice permanently

1. Offboard the practice first if it isn't already — **you can only permanently delete from the
   Offboarded tab.** There is deliberately no way to permanently delete a live practice in one
   step.
2. **Clients** → **Offboarded** tab → find the practice → **⋯** → **Delete permanently**
3. Confirm

**This cannot be undone.** It removes the practice, every report ever generated for them, and
their report history. Their report links stop working immediately. Offboarding is what you want
in almost every case; reach for this only when a practice was created in error or you have been
asked to erase their data.

### Which to use

| Situation | Do this |
|---|---|
| Engagement ended | **Offboard** — keeps the history |
| Offboarded by mistake, or they came back | Fix HubSpot, then **Recover** |
| Created by mistake, duplicate row, or data must be erased | **Delete permanently** |
| Just don't want them in your list this week | **Offboard** — never delete for tidiness |

### Where they show up

| Tab | Shows |
|---|---|
| **All** | Every practice, offboarded included |
| **Active** | Live practices only |
| **Pending** | Awaiting a successful HubSpot sync — including anything just recovered |
| **Offboarded** | Offboarded practices only |

---

## Set up Google Analytics for a practice

GA4 doesn't use a simple API key. It uses a **Google Cloud service account** — a robot
identity with an email and a private key. One service account covers every practice; only
the numeric Property ID is per-practice.

**Already done once, don't repeat:** a Google Cloud project exists with the "Google
Analytics Data API" enabled and a service account created. Its email is the `client_email`
saved under Connections → Google Analytics.

**Per practice, every time:**

1. Get the **Property ID**: in [analytics.google.com](https://analytics.google.com), open
   the practice's property → **Admin → Property Settings** → copy the numeric ID
   (e.g. `367543547`).
2. Grant the service account access. Whoever administers *that property* — it can be the
   practice's own Google login, it doesn't have to be MSP — goes to **Admin → Property
   Access Management → + → Add users**, pastes the service account email, sets the role to
   **Viewer**, and clicks **Add**.
3. Paste the Property ID into that practice's **Edit practice → Data sources → Google
   Analytics** field yourself — no developer needed for this step anymore.

That's the whole per-practice cost. No new service account, no OAuth screen, no code
change.

**Three things that will waste your afternoon if you don't know them:**

- **You cannot log in as a service account.** It has no password and no browser session.
  You always click through Google as yourself; the service account is only ever *granted*
  access.
- **You cannot swap the email for a normal Google account** while keeping the same private
  key, even one that already has access to every client property. The key is
  cryptographically tied to that one service-account identity.
- **A "permission denied" error may not be a permission problem.** If the Analytics Data
  API isn't enabled on the exact Cloud project that owns the service account, Google
  returns an error that looks identical to missing access. Check the API is enabled before
  re-checking Viewer access.

---

## Tracked keywords

**Nothing to add by hand.** Whatever keywords a practice's SEMrush Position Tracking
project tracks are exactly what shows up in their report — the system discovers them
automatically on every generation run and creates the local record itself. A practice
tracking 80+ keywords in SEMrush shows all 80+, paginated 10 per page; add or remove a
keyword in SEMrush and the report picks it up (or drops it) the next time it generates.
Ranking, Keyword Difficulty (KD%), search intent (`C` commercial, `T` transactional,
`I` informational, `N` navigational), and SERP feature count are all pulled live from
SEMrush too — whatever was true when that month generated is what stays on that report
forever, even if the keyword's difficulty or intent shifts later.

**Needs a developer** only to hide one specific SEMrush-tracked keyword from a practice's
report — e.g. an informational long-tail term MSP doesn't want to showcase — without
removing it from SEMrush itself:

```ruby
client = Client.kept.find_by!(name: "Woodside Dental Care")
client.client_keywords.find_by!(keyword: "different kinds of toothache").update!(active: false)
```

That keyword's history is kept, just excluded from future reports until reactivated.

---

## Generate a report

**Reports now generate automatically.** `EnqueueMonthlyReportsJob` runs every 1st of the
month at 4am, creating every active practice's report for the last completed month and
enqueueing generation for it. You don't need to do anything for the normal monthly cycle.

**Needs a developer** only to generate one on demand — a backfill, a retry outside the
schedule, or testing:

```bash
REPORT_MONTH="2026-07" bin/rails reports:generate_real["Woodside Dental Care"]
```

Omitting `REPORT_MONTH` generates last month. The task prints the report link, whether it
succeeded, and any warnings.

Generating is **safe to repeat**. Re-running for the same practice and month replaces that
month's data rather than duplicating it, so a re-run after fixing a credential is always
fine. The scheduled run itself follows the same rule — it skips a practice whose report is
already `ready`, but retries one that previously `failed`.

Attempting the current month is refused — reports cover completed months only.

---

## Get a practice's report link

**Fastest: open that practice's page → Overview tab → Secure report link.** It shows the
full URL for the current month's report with a one-click **Copy** button.

**Or open the Report Log page** — find the practice and month, and click **View** on its
row (only `ready` reports have one). That opens the actual report; copy its URL from the
browser to send it.

The generate command also prints the link at generation time. For anything else — needs a
developer:

```ruby
report = Client.kept.find_by!(name: "Woodside Dental Care").monthly_reports.generated.order(report_month: :desc).first
Rails.application.routes.url_helpers.public_report_url(report.access_token, host: "reports.mysocialpractice.com")
```

**Treat this link like a password.** There is no login on it — anyone holding it can read
that practice's report. Send it to the practice directly; don't post it anywhere public.
Search engines are instructed not to index these pages.

One link per month, permanent. The practice can also switch months from a dropdown in the
report header, so you only need to send the newest one.

---

## Check whether a report worked

**For this cycle, the Dashboard shows it at a glance** — reports generated, failed count,
and a per-client table naming anyone not yet started, still generating, or held on send
(with the real reason, e.g. "HubSpot token rejected").

**For any practice, any month, use the Report Log page.** It lists every generated report
ever, filterable by month and by status (each chip shows a real, live count). This is the
tool for "did last March's report for this specific practice ever send?", which the
Dashboard can't answer since it only covers the current cycle.

**What each status means:**

| Status | Meaning |
|---|---|
| Queued | The report's row exists but generation hasn't started yet — waiting its turn |
| Generating | Being generated right now — pulling data from all five services |
| Ready | Generated successfully, but not yet sent and nothing is holding it |
| Sent | Ready, and actually emailed to the practice |
| Held | Ready, but a send was attempted and blocked on something recoverable (e.g. a rejected credential) |
| Failed | Generation itself failed — a bug, not a degraded section |

**Sent and Held only apply once a report is Ready** — they describe the send step, which is
separate from generation. A queued, generating, or failed report can never be Sent or Held.

For the underlying detail — per-service warnings on an otherwise-successful report —
**needs a developer.**

```ruby
report = Client.kept.find_by!(name: "Woodside Dental Care").monthly_reports.order(report_month: :desc).first
report.generation_status  # "queued", "generating", "ready", or "failed"
report.attempt_count      # how many times generation has been attempted this month

log = report.report_generation_logs.latest_first.first
log.status       # "success" or "failed"
log.error_log    # per-service warnings, even on success
```

**Read `error_log` even when the status is "success".** A report succeeds as long as it
was produced — individual services that failed are recorded as warnings, and those are
exactly the sections that will show placeholders to the practice.

**Nothing pushes an alert when generation fails.** There is no email, no monitoring
service. The Dashboard will show it next time someone looks, and `ReportGenerator` writes a
line to `Rails.logger` on both success and failure (naming the practice, month, and — on
failure — the error), so it's visible to anyone tailing production logs — but nobody is
paged. Checking is still a once-a-day habit, not something that comes to you — that would
need a real notification, which doesn't exist yet.

---

## Re-run a failed report

Fix the cause, then run the same generate command again. Because re-running replaces that
month's data, there's nothing to clean up first.

If the failure was a credential, update it under Connections and re-run. If it was a
missing ID, have a developer set the link and re-run.

---

## Where each ID comes from

Every service identifies a practice differently. This table is the one to keep to hand.

| Service | What's needed | Where to find it |
|---|---|---|
| **HubSpot** | Company ID | The numeric ID in the URL when viewing that company record |
| **GoHighLevel** | Location ID | Sub-account settings — the location, not the agency |
| **Yext** | Entity ID | The entity/location ID on the practice's Yext listing |
| **SEMrush** | Project **and** campaign ID | **See the warning below** |
| **Google Analytics** | Property ID | Analytics → Admin → Property Settings, the numeric ID |

**SEMrush is the one that catches people out.** It needs the **full pair**, joined by an
underscore, taken from the Position Tracking URL:

```
https://semrush.com/tracking/landscape/30632499_5220001.html
                                       └──────┬──────┘
                                   this whole string
```

The shorter project ID shown on the domain overview page is **not** enough. Using it
returns "campaign not found" and the practice's keyword section comes back empty.

---

## What a practice sees when data is missing

**Most of the time, the practice sees nothing missing at all — because HubSpot, Google
Analytics, Yext, and SEMrush are all required for generation to succeed.** If any of them
fails, no report is produced for that practice that month; there's no placeholder to show.
The only genuinely degraded states left are opt-in ones (GoHighLevel, AI SEO) and small
per-field gaps within an otherwise-successful call:

| What's missing | What they see |
|---|---|
| No GoHighLevel link (no scheduler with us) | Appointments and revenue show **?**, with a note that connecting the scheduler will populate them |
| Not enrolled in AI SEO | The "Google & AI Search Performance" section is omitted entirely, not shown empty |
| A practice tracks zero keywords in their SEMrush Position Tracking project | Keyword table empty; nothing else affected — this is a successful call that just returned nothing |
| SEMrush's Keyword Difficulty/Intent/SERP-feature call fails (rankings still succeed) | Rows still show position and movement; KD%, Intent, and SF show blank for that keyword only |
| Nothing genuinely positive to summarise | The highlights paragraph is omitted rather than padded with filler |
| Yext gives no directions/clicks split | That breakdown is omitted; the combined engagement total still shows |
| It's the practice's first month | A "baseline month" introduction replaces the month-over-month summary |

**HubSpot, Google Analytics, Yext, or SEMrush actually failing** (bad credentials, an
expired ID, the service being down) doesn't produce any of the above — it fails the whole
month's generation instead. See ["Check whether a report
worked"](#check-whether-a-report-worked) and
[report-generation](features/report-generation.md#when-data-is-missing) for what that looks
like and how to fix it.

---

## Troubleshooting

**A report generated but a section is empty.**
Read `error_log` on the generation attempt. An empty section almost always means that
service's credential or ID is wrong, not that the practice had no activity.

**A practice says their link doesn't work.**
Check they have the full link — the token is long and easily truncated by chat apps and
email clients. A wrong or partial token shows "Report not found".

**Appointments and revenue show `?` for a practice that does use the scheduler.**
Their GoHighLevel link is missing. Presence of the link is the enrolment signal, so
without it the system never even calls GHL.

**Keyword rankings are empty.**
Most likely the SEMrush ID is the short project ID rather than the full
`project_campaign` pair. Otherwise, check the keywords are tracked in that SEMrush
project and are marked active here.

**Google Analytics says permission denied.**
Two different causes look identical. Confirm the Analytics Data API is enabled on the
Cloud project owning the service account, *then* confirm the service account has Viewer
access on that property.

**A practice enrolled in AI SEO but the section still doesn't appear.**
Enrolment is captured per report at generation time and past reports are never rewritten.
It will appear from the next month's report onward.

**The numbers in an old report look wrong.**
That's by design. Reports are frozen snapshots of what was true when generated, not live
views. They are not recalculated.

**A practice I recovered went back to offboarded on its own.**
HubSpot re-synced and overwrote it. HubSpot is the source of truth for whether a practice is
active, so recovering here only sticks once the practice is marked active in HubSpot too. Fix it
in HubSpot, then recover again — see
[Offboard, recover, or delete a practice](#offboard-recover-or-delete-a-practice).

**A practice I recovered isn't in the Active tab.**
That's expected — a recovered practice comes back as **Pending**, because only a successful
HubSpot sync may promote it to Active. It should move to Active within about an hour, once that
sync runs. If it doesn't, check the HubSpot sync status on its Edit page.

**A practice has vanished from the Clients list.**
Check the **Offboarded** tab, then the **All** tab. The default view is Active only, so an
offboarded practice — whether offboarded by hand or by a HubSpot sync — won't appear in it.
