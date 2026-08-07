---
title: Client onboarding
slug: client-onboarding
status: complete
last_verified: 2026-08-07
related: [admin-panel, integrations]
---

# Client onboarding

> **Status:** complete — HubSpot search import, multi-service domain auto-match, and real-time sync are all live ·
> **Last verified:** 2026-08-07
>
> The streamlined practice onboarding flow: search HubSpot, auto-match all external services
> by domain, and sync details from the source of truth (HubSpot) automatically.

---

## How it works

### Step 1: Add client — choose your entry point

**Path A: Import from HubSpot** (recommended)
1. Go to **Clients** → **Add client** dropdown → **Import from HubSpot**
2. Search by practice name or domain — returns live matches from HubSpot
3. Pick the right company → click "Use this"
4. Land on the New form with:
   - Practice **name pre-filled** from HubSpot
   - **HubSpot service ID pre-filled** (but **not synced yet** — just the ID is ready)
   - Optional fields (website, phone, address) ready for you to fill if needed
5. Click **"Add client"** → **This triggers the sync**:
   - Creates the practice
   - Immediately enqueues `SyncHubspotClientJob`
   - Fetches onboarding_status, onboarded_at, AI SEO enrollment from HubSpot (usually ~5 seconds)
   - Edit page shows "Syncing…" then "Synced just now"

**Path B: Add manually**
1. Go to **Clients** → **Add client** dropdown → **Add manually**
2. Enter practice name, website, phone, and address by hand
3. Land on the Edit form (same as Path A after this)

Both paths flow to the same form, so they converge immediately.

### Step 2: Link HubSpot (mandatory for onboarding)

On the Edit form (Data sources section):
1. **HubSpot is the first field** — the source of truth for onboarding status, date, and AI SEO enrollment
2. Paste the HubSpot company ID
3. Save immediately triggers `SyncHubspotClientJob` — syncs name, address, website, onboarding status, and AI SEO enrollment
4. A green dot + "Synced *n* ago" label appears once it succeeds
5. **A practice cannot reach Active status until HubSpot sync succeeds**

### Step 3: Auto-match other services (optional at first, mandatory once linked)

**Sync services button** (only visible once the client is saved):
1. Shows three fields ready for matching: GoHighLevel, Yext, SEMrush
2. Click **Sync services** → job checks all three services simultaneously for domain matches
3. Each service shows:
   - **Searching...** with animated spinner + countdown (estimated time from last 3-4 checks)
   - **Match found** with company name, domain, ID, + "Use this" + "×" buttons
   - **No match found** — ID must be entered by hand
   - **Couldn't reach** — API down; try again later
4. Click **Use this** → fills the ID field, suggestion disappears
5. Click **×** → removes unwanted suggestion, can enter ID manually instead
6. Save to persist all filled IDs

**Unsaved changes warning**: Try to navigate away with edits → browser warns and prevents accidental loss.

---

## The data flow

### HubSpot sync (happens immediately on ID save)

```
User enters HubSpot company ID → Save form
  ↓
ClientServiceLink after_commit callback enqueues SyncHubspotClientJob
  ↓
Job calls SyncClientFromHubspot.call
  ↓
Fetches from HubSpot: name, address, website, active (→ onboarding_status), gmb_seo_start_date (→ onboarded_at), service_purchased (→ ai_seo_enrolled)
  ↓
Updates Client row + records last_synced_at / last_sync_error on the link
  ↓
Edit form shows green dot + "Synced 1 minute ago"
```

**Automatic daily re-sync**: `EnqueueHubspotSyncJob` (runs daily) enqueues a sync for every client with a HubSpot ID.

### Multi-service domain matching (background job, real-time broadcast)

```
User clicks "Sync services" → controller broadcasts "Searching..." placeholder to each service
  ↓
SyncClientServicesJob.perform_later enqueued
  ↓
Job calls SyncServicesChecker.call_with_yields
  ↓
For each unlinked service (GHL, Yext, SEMrush):
  1. Measure start time
  2. Call the matcher (GhlLocationMatcher, YextEntityMatcher, SemrushProjectMatcher)
  3. Matcher normalizes client.website_url (strip scheme, www, trailing slash, downcase)
  4. Matcher queries the service API for all records, normalizes each domain, compares
  5. Returns Match (found), false (not found), or raises (error)
  6. Job records ServiceSyncLog: duration_ms, status (success/not_found/error), error_message
  7. Job broadcasts result via Turbo::StreamsChannel → "Use this" card OR "No match found" label
  ↓
Each service updates independently as it completes (no waiting for all three)
```

The countdown timer on each service shows the **real average from the last 3–4 successful syncs** of that service — not a guess.

---

## Key decisions

**Why HubSpot first?**
It's the mandatory, single source of truth for whether a practice can go Active. Putting it first makes that dependency visible.

**Why auto-match only unlinked services?**
Protects against accidentally overwriting a hand-entered ID. Once a service is linked, you must manually change it (either in Edit or by modifying the source system and re-syncing).

**Why is the timer per-service, not total?**
Each service runs sequentially (to avoid overloading APIs), so a realistic timer for each tells the user when they'll see that specific result. The total time varies based on how many services need checking (2-3 services × ~2.5 seconds each).

**Why does suggestion removal require a click?**
Accidental dismissals (fat-finger on the × button) are worse than a suggestion left on screen — the × is there, but the user can still type an ID if they prefer it.

**Why unsaved changes warning?**
The form touches five service IDs plus practice details. Losing edits mid-sync discovery is frustrating.

---

## When data is missing

| Situation | What's shown |
|---|---|
| HubSpot ID entered but sync hasn't completed | "Syncing…" (amber dot) |
| HubSpot sync failed (bad ID, no access, timeout) | "Sync failed" + reason (red dot) |
| No HubSpot ID linked yet | "Not linked" (grey dot) + amber notice (can't reach Active) |
| Sync services finds a match | Match card with "Use this" button |
| Sync services finds no match | "No match found matching this practice's website." |
| API unreachable during sync | "Couldn't reach this service — try again in a moment." (red) |

---

## Credential requirements

| Service | Needed for match? | Where | Type |
|---|---|---|---|
| HubSpot | Yes (mandatory for Active) | Agency-wide Connections | API key (Bearer token from OAuth) |
| GoHighLevel | Yes (required to auto-match) | Agency-wide Connections | OAuth token (set up once, location tokens minted per-client) |
| Yext | Yes (optional feature) | Agency-wide Connections | API key (`api_key`, `v` version param) |
| SEMrush | Yes (optional feature) | Agency-wide Connections | API key (`key`) |
| Google Analytics | No (only for report data) | Agency-wide Connections | Service account (email + private key) |

GHL and HubSpot are mandatory for the system to function. Yext and SEMrush are optional — if not configured, their rows show "Not configured" and Sync services skips them.

---

## How MSP staff use it

### Adding a new practice (typical flow)

1. **Clients** → **Add client** → **Import from HubSpot**
2. Search for the practice by name or domain
3. Pick it from the results
4. Details auto-fill
5. Save (creates the client, enqueues HubSpot sync)
6. Wait ~10 seconds for sync to complete (Edit page shows "Syncing…" → "Synced just now")
7. Click **Sync services** (only appears after save)
8. Wait ~5-7 seconds (depends on number of unlinked services)
9. Review suggestions, click "Use this" for each one, ignore any that are wrong
10. Click **Save practice**
11. **Done** — all five services are now linked

### Adding manually if HubSpot search fails

1. **Clients** → **Add client** → **Add manually**
2. Type name, website, phone (address optional)
3. Save (creates the client)
4. Link HubSpot by hand if you have the ID
5. Same Sync services flow from step 7 above

### Re-syncing if a service ID changed externally

1. Go to the client's Edit page
2. Click **Sync services** again (only checks unlinked services, ignores already-linked ones)
3. Or go to **Connections** and add the credential there, then re-sync

---

## For developers

### Services checker orchestration

`SyncServicesChecker` is the central coordinator:
- `unlinked_services(client)` — returns which of [ghl, yext, semrush] have blank `external_id`
- `call_with_yields` — runs each in sequence, yielding(service, outcome) as each completes
- Each outcome is: `Match` (found), `false` (not found), or an exception (caught → :error)

### Matchers (domain-based)

Each matcher: `new(client).call` → `Match | false | raises`

| Matcher | API | Key field | Match structure |
|---|---|---|---|
| `GhlLocationMatcher` | `GET /locations/search` | `location.website` | `Match(location_id, name, website)` |
| `YextEntityMatcher` | `GET /v2/accounts/me/entities` | `entity.websiteUrl.url` | `Match(entity_id, name, website)` |
| `SemrushProjectMatcher` | `GET /management/v1/projects` + campaigns | `project.url` + campaign domain | `Match(project_campaign_id, name, domain)` |

Each uses `NormalizesDomain` concern to strip scheme, www, trailing slash, downcase before comparing.

### Domain normalization

All matchers use the same normalization:
```ruby
def normalize_domain(url)
  url.to_s.sub(%r{\Ahttps?://}, "").sub(/\Awww\./, "").sub(%r{/\z}, "").downcase
end
```

So `https://www.example.com/` and `http://example.com` and `EXAMPLE.COM` all normalize to `example.com`.

### Timing & estimates

`ServiceSyncLog` tracks each check:
- `client_id`, `service`, `duration_ms`, `status` (success/not_found/error), `error_message`, `created_at`

`ServiceSyncLog.average_duration_for(service)` returns the average of the last 3-4 **successful** checks:
```ruby
def self.average_duration_for(service)
  where(service: service, status: :success)
    .order(created_at: :desc)
    .limit(4)
    .average(:duration_ms)
    .to_i
end
```

Defaults to 2500ms if no history exists.

### Unsaved changes warning

`UnsavedChangesController` (Stimulus):
- Listens to form `change` events
- On link click, shows `confirm()` dialog if changes exist
- Also guards on `beforeunload` (browser back/reload)

---

## Key files

| Path | Role |
|---|---|
| `app/controllers/clients/hubspot_searches_controller.rb` | HubSpot search endpoint (index action, form GET) |
| `app/controllers/clients/sync_services_controller.rb` | "Sync services" button handler (broadcasts initial "Searching..." placeholders) |
| `app/services/hubspot_company_searcher.rb` | HubSpot Search API wrapper — searches by name/domain |
| `app/services/ghl_location_matcher.rb` | Domain match against GHL locations |
| `app/services/yext_entity_matcher.rb` | Domain match against Yext entities |
| `app/services/semrush_project_matcher.rb` | Domain match against SEMrush projects (includes campaign sub-resource) |
| `app/services/sync_services_checker.rb` | Orchestrates all three matchers, yields results as they complete |
| `app/services/concerns/normalizes_domain.rb` | Shared domain normalization logic |
| `app/jobs/sync_client_services_job.rb` | Background job (runs the checker, broadcasts each result, logs timing) |
| `app/models/service_sync_log.rb` | Logs each service check attempt (duration, status, error) |
| `app/views/clients/hubspot_searches/index.html.erb` | HubSpot search UI (search box + results list) |
| `app/views/clients/_form.html.erb` | Edit/Add form (includes "Sync services" button) |
| `app/views/clients/_service_outcome.html.erb` | Per-service result card (Searching/Found/Not found/Error states) |
| `app/javascript/controllers/apply_suggestion_controller.js` | "Use this" button behavior (fills input, removes card) |
| `app/javascript/controllers/dismiss_suggestion_controller.js` | "×" button behavior (removes card) |
| `app/javascript/controllers/service_timer_controller.js` | Countdown timer (estimated per-service duration) |
| `app/javascript/controllers/unsaved_changes_controller.js` | Warns before navigating away with unsaved edits |
| `app/javascript/controllers/dropdown_controller.js` | Add client dropdown menu (Import from HubSpot / Add manually) |
| `test/controllers/clients/sync_services_controller_test.rb` | Tests broadcast response, role gating, job enqueue |
| `test/services/sync_services_checker_test.rb` | Tests matcher orchestration, partial failures |
| `test/models/service_sync_log_test.rb` | Tests timing/status logging, average calculation |

---

## Testing notes

- `SyncServicesChecker` is unit-tested with WebMock stubs for each adapter (real response shapes)
- `SyncClientServicesJob` is integration-tested (enqueue + broadcast response)
- Controller is integration-tested (auth, job enqueue, turbo_stream response)
- HubSpot search is integration-tested (API call, result parsing, pagination)
- No system/Capybara tests yet (would require browser-based Turbo interaction verification)

