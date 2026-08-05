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
| GoHighLevel | Access Token |
| Yext | API Key |
| SEMrush | API Key |
| Google Analytics | Client Email **and** Private Key (see [GA4 setup](#set-up-google-analytics-for-a-practice)) |

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

**These statuses are not yet updated automatically.** Nothing currently sets them by
testing the credential, so treat them as a note rather than live monitoring. The reliable
way to know a service is working is to [generate a report and read the
warnings](#check-whether-a-report-worked).

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

**Go to Clients → Add client.** You have two ways to fill it in, and you can mix them:

1. **Enter the HubSpot company ID** (in Data sources, at the bottom) and leave the rest
   blank. Saving immediately pulls the practice's name, address, website, onboarding
   status, and AI SEO enrolment from HubSpot — you don't have to type any of it. The
   practice is created right away with a placeholder name ("Syncing from HubSpot…") that's
   replaced the moment the sync completes, usually within a few seconds.
2. **Type the details in by hand** — name, website, phone, address — and save without a
   HubSpot ID. The practice is created as **Pending**.

**A practice only reaches Active once a HubSpot sync has succeeded for it.**
`onboarding_status`, `onboarded_at`, and AI SEO enrolment are owned by HubSpot — they are
not fields you set on this form, they're read-only, and they stay "Pending" / unset until a
real HubSpot company record has been linked and synced at least once. This is deliberate:
it stops a practice from silently drifting out of sync with what HubSpot actually says
about them. Once a HubSpot ID is linked, it re-syncs automatically once a day after that
too, so this isn't a one-time action.

**What it actually reads off the HubSpot Company record:**

| HubSpot property | Goes to |
|---|---|
| Company name | Practice name |
| Address | Practice address |
| Website | Website URL |
| Active (checkbox) | Onboarding status — checked → **Active**, unchecked → **Offboarded** |
| GMB SEO Start Date | Onboarded on |
| Services Purchased | AI SEO enrolled — checked if this multi-select includes **"AI SEO"** |

If the "Active" checkbox has never been set on the HubSpot side, that practice can't
show as Active here either — check that property in HubSpot first before assuming the
sync is broken.

**`website_url`** is used to find their sitemap and to match their SEMrush rankings, so it
must be the real site.

---

## Connect a practice to the data sources

**Go to the practice's page → Edit practice.** The Data sources section lists all five
services — HubSpot, GoHighLevel, Yext, SEMrush, Google Analytics — each with one ID field.
See [where each ID comes from](#where-each-id-comes-from). Paste in the ID and **Save
practice**; a status dot next to each field shows Not linked / Linked (or, for HubSpot
specifically, Syncing… / Synced / Sync failed, since that one is a live sync rather than
just an ID used at report time — see "Add a new practice" above).

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
