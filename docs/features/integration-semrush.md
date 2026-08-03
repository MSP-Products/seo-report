---
title: SEMrush integration
slug: integration-semrush
status: shipped
last_verified: 2026-08-04
related: [integrations, monthly-report, report-generation]
---

# SEMrush integration

> **Status:** shipped — both endpoints confirmed live · **Last verified:** 2026-08-04
>
> SEMrush supplies the report's keyword performance section: which search terms are
> tracked at all, where each currently ranks, how difficult it is to rank for, its search
> intent, and its SERP feature count.

---

## For everyone

### Purpose

The set of tracked search terms — "dentist ventura", "dental implants near me" — is
**discovered from SEMrush**, not curated locally. Whatever a practice's SEMrush Position
Tracking project tracks is exactly what shows up in their report; nobody adds keywords by
hand on our side. A practice tracking 80+ keywords in SEMrush shows 80+ in the report,
paginated 10 per page.

### What it provides

Current position per tracked keyword, an approximation of the traffic that keyword could
bring, how difficult it is to rank for (KD%), its search intent, and how many SERP features
appear alongside it.

**It does not provide last month's position.** Month-over-month movement in the report is
MSP's own record: last month's report's position is carried forward as this month's
"previous". SEMrush is only ever asked what is true now.

### Setting it up

- **Credential:** an API key, agency-wide, entered under Connections.
- **Per practice:** the Position Tracking **project and campaign ID**, joined by an
  underscore.

**This is the single most common setup mistake in the system.** The ID must be the full
pair from the Position Tracking URL:

```
https://semrush.com/tracking/landscape/30632499_5220001.html
                                       └──────┬──────┘
                                       use this whole string
```

The shorter project ID shown on the domain overview page returns "campaign not found" and
the practice's keyword section comes back empty.

**Nothing else to set up.** Whichever keywords are tracked inside that SEMrush project are
what show up in the report — add or remove one in SEMrush and the report reflects it on the
next generation run. No local keyword list to maintain.

### When data is missing

| Situation | Effect |
|---|---|
| No project ID recorded | The call is skipped; keyword section empty |
| The SEMrush project tracks no keywords yet | Succeeds with an empty list; no local records created |
| SEMrush reports the term as not ranking | Position shown as unranked, not as zero |
| The API fails | Warning recorded; keyword section empty; rest of report unaffected |
| MSP marks a keyword inactive | It's excluded from the report going forward, but its history and the SEMrush tracking itself are untouched |

### Known limits

- **"Potential traffic" and "Growth" are both approximations.** SEMrush exposes no
  dedicated figure for either on this report. Potential traffic uses the closest available
  signal (traffic share for the most recent tracked date); growth is the change in that
  same traffic share across the earliest and latest tracked dates in one response. Treat
  both as indicative, not exact.
- **Growth is nil for a practice's first month or two.** It needs two distinct tracked
  dates in the Position Tracking response, which a newly-added project doesn't have yet.
- **Keyword Difficulty, Intent, and SERP Feature count all come from a second, genuinely
  separate SEMrush call** (not part of Position Tracking) and can fail independently — see
  Failure modes.
- **The SF column is a count, not a list of feature names.** SEMrush returns which SERP
  features are present as numeric codes; the report shows how many, not which ones.
- **Only the practice's own domain is measured**, matched by a wildcard pattern built from
  their website address. If the tracking project was set up against a different domain
  form, positions come back empty.

### FAQ

**Q: The keyword table is empty but we know we rank.**
A: Almost always the project ID. Check it is the full `project_campaign` pair, then check
the practice actually has keywords tracked in that SEMrush project.

**Q: We want a specific SEMrush-tracked keyword to stop showing on the report.**
A: A developer marks it `active: false` on `ClientKeyword` — see
[MSP-GUIDE](../MSP-GUIDE.md#tracked-keywords). It keeps its history; it's just excluded
from future reports. Nothing to do in SEMrush itself.

**Q: A practice has a lot of keywords — is the report one giant table?**
A: No, it paginates at 10 keywords per page. The summary counts (gained/held/dropped,
top-10/top-3) still reflect *all* tracked keywords, not just the visible page.

**Q: Why does the report show a different position than SEMrush's dashboard?**
A: The report shows the most recent position within the report month. SEMrush's dashboard
shows today's.

**Q: A keyword shows a position but no movement arrow.**
A: Movement needs a position in the *previous* month's report. A keyword added recently has
no prior record, so it is shown as neither gained nor dropped — deliberately, so new
keywords do not pollute the gained/dropped counts.

---

## For developers

### API reference

**Base URL** `https://api.semrush.com`
**Auth** `key` query parameter

#### Position tracking — `GET /reports/v1/projects/{project_campaign_id}/tracking/`

| Parameter | Value |
|---|---|
| `key` | API key |
| `type` | `tracking_position_organic` |
| `action` | `report` |
| `url` | the wildcard mask, e.g. `*.example.com/*` |
| `display_limit` | `500` |

#### Keyword Overview — `GET /` (classic Analytics API, bulk)

| Parameter | Value |
|---|---|
| `key` | API key |
| `type` | `phrase_this` |
| `database` | `us` — MSP's practices are all US-based |
| `phrase` | semicolon-joined keyword phrases, up to 100 per request |
| `export_columns` | `Ph,Kd,In,Fk` |

**Response is semicolon-delimited CSV** (the classic Analytics API shape), not JSON:

```
Keyword;Keyword Difficulty Index;Intent;Keywords SERP Features
cosmetic dentistry;81;0;3,6,9,13,21,36,43
```

Confirmed live against MSP's real account (see Field mapping) — a request without
`database` fails with `ERROR 46 :: MANDATORY PARAMETER database NOT SET OR EMPTY`.

**`type=phrase_this` is documented by SEMrush as a single-keyword "Keyword Overview"
report, but confirmed live to accept the same semicolon-joined bulk `phrase` list as the
KD-only endpoint** — one call returns Kd, Intent, and SERP Features together for up to 100
keywords, so there's no separate bulk-KD-only call to maintain.

| `In` code | Meaning | Confirmed how |
|---|---|---|
| `0` | Commercial | Live: "cosmetic dentistry" → `0` |
| `1` | Informational | Live: "root canal", "dental implants" → `1` |
| `2` | Navigational | **Not confirmed against a real example** — no tracked keyword returned it live. Documented by SEMrush alongside the other three; treat with lower confidence until seen |
| `3` | Transactional | Live: "dentist near me" → `3` |

`Fk` is a comma-separated list of SERP feature type codes (e.g. `3,6,9,13,21,36,43`) — SEMrush's
numeric-to-name mapping for these codes was not looked up, since the report only needs a
count (see Field mapping).

Three things confirmed live that contradict the obvious assumptions about Position Tracking:

1. **No `/rankings` suffix** — the path ends at `/tracking/`.
2. **The response is JSON**, not the semicolon-delimited text SEMrush's classic Domain
   Analytics reports return.
3. **`export_columns` is silently ignored** — this report always returns its own fixed
   field set.

**Response shape** — rows are keyed by index under `data`, not an array:

```
{ "data": {
    "0": { "Ph": "dentist near me",
           "Fi": { "*.example.com/*": 7 },
           "Tr": { "20260601": { "*.example.com/*": 0.50 },
                   "20260630": { "*.example.com/*": 0.81 } } } } }
```

| Key | Meaning |
|---|---|
| `Ph` | The keyword phrase |
| `Fi` | Most recent position in the range, keyed by URL mask. `"-"` means not ranked |
| `Be` | Earliest position in the range — **not used**; our own history is authoritative |
| `Tr` | Traffic share, keyed by date then URL mask |
| `Dt` | Per-date breakdown — used to verify `Fi`/`Be` semantics, not read in code |

### Field mapping

**`ClientKeyword` records are discovered, not matched.** Every phrase in the Position
Tracking response is `create_or_find_by!`'d onto `client.client_keywords` (stripped +
downcased by `ClientKeyword#normalize_keyword`), then filtered to `active?` before being
written to `ReportKeywordRanking`. There is no longer a pre-existing list to match against
— the tracked set *is* whatever SEMrush's response contains this run.

| Source | Column | Notes |
|---|---|---|
| `Ph` (Position Tracking), `create_or_find_by!`'d | `keyword_id` | Auto-created if not already present; `active: false` excludes it from `rankings` without deleting it |
| `Fi[url_mask]` | `position` | Non-numeric (`"-"`) becomes `nil` |
| `Tr[latest_date][url_mask]` | `potential_traffic` | Latest date, not earliest. Approximation |
| `Tr[latest] - Tr[earliest]` (same response) | `growth` | Nil if only one tracked date exists |
| `Kd` from the bulk overview response | `keyword_difficulty` | Matched by normalized phrase; nil if the overview call fails — see Failure modes |
| `In` from the bulk overview response | `intent` | Mapped `0/1/2/3` → `C/I/N/T`; nil if unrecognized or the call fails |
| `Fk` from the bulk overview response | `serp_features` | Count of comma-separated feature codes, not the decoded names; nil if the call fails |
| *from last month's report* | `previous_position` | Written by `ReportGenerator`, not this adapter |

**`growth`, `keyword_difficulty`, `intent`, and `serp_features` are all written to
`ReportKeywordRanking`, not `ClientKeyword`** — they're per-report-month snapshots like
`position`, not a fact about the keyword that holds forever. `ClientKeyword#keyword_difficulty`,
`#intent`, and `#serp_features` still exist in the schema but are no longer read anywhere;
they're seed-data-only legacy from before this adapter fetched them live, and are candidates
for removal in a future migration (see Gotchas).

The URL mask is derived from `client.website_url` by stripping scheme, `www.` and any
trailing slash, then wrapping: `*.{domain}/*`.

**A keyword only produces a row if SEMrush's Position Tracking response includes it this
run.** There's no "tracked here but SEMrush stopped returning it" ghost-row case anymore —
if SEMrush drops a keyword from the project, it simply stops appearing in future reports.
Past reports are untouched (frozen snapshots).

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/semrush_adapter.rb` | The whole integration, incl. auto-discovery |
| `app/models/client_keyword.rb` | Auto-created records, `normalize_keyword`, the `active` opt-out scope |
| `app/models/report_keyword_ranking.rb` | Per-report position record |
| `app/services/report_generator.rb` | `sync_keywords` — carries `previous_position` forward |
| `app/presenters/report_presenter.rb` | `keyword_movement`, gained/held/dropped folds, and keyword-table pagination (`paginated_keyword_rows`, `keyword_page`, `keyword_total_pages`) |
| `app/controllers/reports_controller.rb` | Passes `params[:keyword_page]` into the presenter |
| `app/models/monthly_report.rb` | `for_public_view` — the report's preload scope |
| `app/views/reports/_keyword_performance.html.erb` | Section chrome + pagination controls |
| `app/views/reports/_keyword_table.html.erb` | The table itself, rendered once per page |
| `db/migrate/20260803221106_add_keyword_difficulty_to_report_keyword_rankings.rb` | Adds the per-report KD% column |
| `db/migrate/20260803222447_add_intent_and_serp_features_to_report_keyword_rankings.rb` | Adds the per-report Intent + SF columns |
| `db/migrate/20260803225128_add_unique_index_to_client_keywords_on_client_id_and_keyword.rb` | Backs auto-discovery's race-safety |
| `app/helpers/reports_helper.rb` | `intent_badge_class`, `keyword_difficulty_class` |
| `test/services/adapters/semrush_adapter_test.rb` | Auto-creation, dedup/reuse, the inactive-exclusion case, `"-"` handling, growth derivation, overview success/degrade |
| `test/models/client_keyword_test.rb` | Normalization, and why the DB index (not a validation) is what backs `create_or_find_by!` |
| `test/controllers/reports_controller_test.rb` | Keyword-table pagination |

### Data

| Model / table | Role |
|---|---|
| `ClientKeyword` | `keyword` (auto-created, normalized), `active` (the opt-out flag), `intent`/`keyword_difficulty`/`serp_features` (all legacy, unread — see Gotchas) |
| `ReportKeywordRanking` | `position`, `previous_position`, `potential_traffic`, `growth`, `keyword_difficulty`, `intent`, `serp_features` |

`report_keyword_rankings` is unique on `(report_id, keyword_id)` at the database level.
`client_keywords` is unique on `(client_id, keyword)` — this is what makes auto-discovery
safe to re-run without duplicating a keyword every month.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| Missing `external_id` | `Result.failure("semrush: no project id configured…")` | `error_log` |
| SEMrush project tracks no keywords | `Result.success(rankings: [])` — **not** a failure, no `ClientKeyword` created | Nothing |
| Position Tracking HTTP error after retries | `Result.failure` — the whole call fails | `error_log` |
| Keyword Overview HTTP error | **Degrades independently** — rankings still succeed, `keyword_difficulty`/`intent`/`serp_features` are all `nil` for every keyword this run | **Nowhere** |
| Wrong ID form (project only) | SEMrush returns "campaign not found" | `error_log` |

The overview row is worth knowing: unlike Position Tracking, a failed overview call never
fails the report — it's supplementary, not load-bearing, so it silently leaves KD%/Intent/SF
blank rather than losing the whole keyword section.

### Gotchas

- **The ID is `project_campaign`, not the project ID.** This is the mistake to check first
  on any empty keyword section.
- **`ClientKeyword` rows are now auto-created, every run, for every phrase SEMrush
  returns.** `client_keywords.create!` by a developer is no longer part of the normal
  flow — see [MSP-GUIDE](../MSP-GUIDE.md#tracked-keywords). The only manual action left is
  marking one `active: false` to exclude it.
- **`create_or_find_by!`'s race-safe fallback does not re-run `normalize_keyword`.** It's
  only correct because `SemrushAdapter` always passes an already-stripped-and-downcased
  phrase. See the comment on `find_or_create_keyword` and
  `test/models/client_keyword_test.rb` before changing either side of this.
- **There's no `validates :uniqueness` on `ClientKeyword#keyword`, deliberately.** Adding
  one back would make `create_or_find_by!` raise `RecordInvalid` on the initial check
  instead of falling through to its DB-level rescue — the unique index is the actual
  invariant now, not a Rails-level validation.
- **`display_limit` is 500**, comfortably above MSP's current 140-keyword SEMrush plan
  cap. Bump it if the plan is ever upgraded to a higher tier.
- **`previous_position` never comes from SEMrush.** Do not be tempted by `Be` or a diff
  field — our own month-over-month record is the source of truth, and switching would break
  the gained/held/dropped counts.
- **`potential_traffic` reads the latest date in `Tr`**, not the earliest, and is an
  approximation of a metric SEMrush does not actually expose.
- **A keyword with no previous position is neither gained nor dropped** — see
  `ReportPresenter#keyword_movement`. New keywords must not skew the summary counts.
- **The Keyword Overview call is a different base path (`/`) and a different response
  format (semicolon CSV) from Position Tracking (`/reports/v1/...`, JSON).** Don't assume
  the two share a parser.
- **`OVERVIEW_BATCH_SIZE` (100) exists to keep one request under SEMrush's phrase-count
  cap** — a practice tracking more than 100 keywords issues multiple bulk overview
  requests, not a pagination request.
- **`ClientKeyword#keyword_difficulty`/`#intent`/`#serp_features` are all legacy and
  unread.** The live values are on `ReportKeywordRanking` now; don't reintroduce a read
  from the old columns.
- **SEMrush's Intent code `2` (Navigational) is unconfirmed against a real keyword.** The
  mapping is documented by SEMrush, not observed live — if a report ever shows an
  unexpected blank Intent badge, check whether the raw code is something outside `0`-`3`.
- **SF is a count, not a decoded list.** If a future report needs to show *which* SERP
  features are present (not just how many), the numeric-to-name mapping for `Fk` codes
  still needs to be looked up from SEMrush's docs — it wasn't needed for this pass.
- **The keyword table paginates at `ReportPresenter::KEYWORDS_PER_PAGE` (10)**, via a plain
  `?keyword_page=N` query param — no JS required, no pagination gem. The summary counts
  (`keywords_top10_count`, `keyword_gained_count`, etc.) fold over the *full* `keyword_rows`
  set regardless of page; only the rendered table itself is sliced.

### Not built yet

- Dropping the now-unused `client_keywords.keyword_difficulty`/`intent`/`serp_features`
  columns — additive-then-remove per CLAUDE.md, not done in the same change that stopped
  reading them.
- Decoding `Fk`'s numeric SERP feature codes into named features, if MSP ever wants more
  than a count.
- A self-service admin UI for marking a keyword inactive — today it's a console command,
  same "needs a developer" gap as the rest of the stubbed admin panel.

---

## Changing this feature

- **Keep producing a row for every keyword in that run's Position Tracking response**,
  ranked or not.
- **Keep `previous_position` sourced from our own prior report.**
- **Keep the not-ranked case as `nil`, never `0`** — position 0 would sort as the best
  possible rank.
- **Keep `keyword_difficulty`, `intent`, `serp_features`, and `growth` on
  `ReportKeywordRanking`, not `ClientKeyword`.** All four are per-report snapshots — writing
  them back onto the keyword definition would let a later month's value silently rewrite
  what an earlier report showed.
- **A failed Keyword Overview call must keep degrading independently**, never fail the
  whole adapter — it's supplementary, unlike Position Tracking.
- **Keep `serp_features` a count.** If MSP later wants named features, that's an addition
  (a new column or a decoded list), not a change to the existing integer.
- **Don't reintroduce a manual "add a tracked keyword" flow.** The whole point of
  auto-discovery is that SEMrush is the one place MSP manages the tracked set; a competing
  local add-path would raise the same "which one wins" question `sync_hubspot` already
  answers for practice details.
- **Don't add a `validates :uniqueness` back onto `ClientKeyword#keyword`.** It would break
  `create_or_find_by!`'s race-safety — see Gotchas.
- **Keep `ClientKeyword#normalize_keyword` in sync with however `SemrushAdapter` builds its
  lookup keys.** Both sides assuming "stripped + downcased" is what makes the DB index
  alone sufficient; changing one without the other reopens the duplication risk this was
  built to close.
