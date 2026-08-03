# MSP guide

How to run the SEO reporting system. Written for MSP staff, organised by the task you're
trying to do.

> **Read this first.** The admin panel has **one working page** today: Connections.
> Adding a practice, connecting it to a data source, getting a report's link, and checking
> whether generation worked are all commands a developer runs. Where that's the case, this
> guide says so and gives the exact command. It is not a permanent state, but it is
> today's state, and pretending otherwise would waste your time.
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
- **Needs a developer**
  - [Add a new practice](#add-a-new-practice)
  - [Connect a practice to the data sources](#connect-a-practice-to-the-data-sources)
  - [Set up Google Analytics for a practice](#set-up-google-analytics-for-a-practice)
  - [Add tracked keywords](#add-tracked-keywords)
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
a developer:

```ruby
AdminUser.create!(email: "someone@mysocialpractice.com", password: "a-long-password", role: "admin")
```

Password must be at least 8 characters. To reset one, a developer sets a new password on
the account the same way.

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

## Add a new practice

**Needs a developer.** There is no Clients page yet.

```ruby
Client.create!(
  name: "Woodside Dental Care",
  website_url: "www.woodsidedentalcare.net",
  address: "10883 Telegraph Rd, Ventura, CA 93004",
  onboarding_status: "active",
  onboarded_at: Time.current,
  ai_seo_enrolled: true
)
```

- **`ai_seo_enrolled`** decides whether the AI search section appears in their reports.
- **`website_url`** is used to find their sitemap and to match their SEMrush rankings, so
  it must be the real site.
- HubSpot is the source of truth for name, address, website, onboarding status and AI SEO
  enrolment — **whatever HubSpot says overwrites what you type here** on the next report
  run.

---

## Connect a practice to the data sources

**Needs a developer.** Each service identifies the practice by its own ID, so every
practice needs one link per service. See [where each ID comes
from](#where-each-id-comes-from).

The supported route today is a rake task driven by environment variables:

```bash
REAL_CLIENT_NAME="Woodside Dental Care" \
HUBSPOT_ACCESS_TOKEN="..." HUBSPOT_COMPANY_ID="..." \
YEXT_API_KEY="..." YEXT_ENTITY_ID="..." \
SEMRUSH_API_KEY="..." SEMRUSH_PROJECT_ID="30632499_5220001" \
GA4_PROPERTY_ID="367543547" \
bin/rails reports:seed_real_client
```

Any service whose variables are missing is skipped and reported as such. A practice with
no link for a service simply has that section unavailable in their report.

**GoHighLevel is special:** whether a GHL link exists *is* the "does this practice use our
appointment scheduler" signal. No link means appointments and revenue show `?`, and the
system never calls GHL at all for that practice.

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
3. Give the Property ID to a developer to save against the practice.

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

## Add tracked keywords

**Needs a developer.** These are the search terms shown in the report's keyword table.

```ruby
client = Client.kept.find_by!(name: "Woodside Dental Care")
client.client_keywords.create!(keyword: "dentist ventura", intent: "C")
```

`intent` is why someone searched: `C` commercial, `T` transactional, `I` informational,
`N` navigational. A keyword can carry more than one (`"I C"`).

New keywords are active automatically — nothing extra to set. To stop tracking one
without losing its history, a developer marks it inactive rather than deleting it.

The keyword must **also** be tracked in the practice's SEMrush Position Tracking project.
Adding it here alone gets you a row in the report with no ranking against it.

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

**Needs a developer.** The generate command prints it. Otherwise:

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

**Needs a developer.** Every attempt is recorded, successful or not.

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

**Nothing alerts anyone when generation fails.** There is no email, no dashboard, no
monitoring. `ReportGenerator` writes a line to `Rails.logger` on both success and failure
(naming the practice, month, and — on failure — the error), so it's visible to anyone
tailing production logs, but nothing pushes it to a person. Checking is a manual step until
a Dashboard page exists.

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

The report never shows an error and never invents a number. Each missing source produces
a specific, deliberate placeholder — worth knowing, because practices ask.

| What's missing | What they see |
|---|---|
| No GoHighLevel link (no scheduler with us) | Appointments and revenue show **?**, with a note that connecting the scheduler will populate them |
| Google Analytics not connected | Visits show **—** and "Google Analytics isn't connected yet for this practice"; the traffic-sources breakdown is hidden |
| Not enrolled in AI SEO | The "Google & AI Search Performance" section is omitted entirely, not shown empty |
| Yext unavailable that month | Citation figures blank; nothing else affected |
| SEMrush unavailable, or keywords not tracked | Keyword table empty; nothing else affected |
| Nothing genuinely positive to summarise | The highlights paragraph is omitted rather than padded with filler |
| Yext gives no directions/clicks split | That breakdown is omitted; the combined engagement total still shows |
| It's the practice's first month | A "baseline month" introduction replaces the month-over-month summary |

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
