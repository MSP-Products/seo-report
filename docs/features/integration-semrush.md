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
> SEMrush supplies the report's keyword performance section: where each tracked search term
> currently ranks, and how difficult it is to rank for.

---

## For everyone

### Purpose

MSP tracks a set of search terms per practice — "dentist ventura", "dental implants near
me" — and SEMrush reports where the practice's website ranks for each. That feeds the
report's keyword table.

### What it provides

Current position per tracked keyword, and an approximation of the traffic that keyword
could bring.

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

Keywords must also be **tracked inside that SEMrush project**. Adding a keyword on our side
alone produces a row in the report with no ranking against it.

### When data is missing

| Situation | Effect |
|---|---|
| No project ID recorded | The call is skipped; keyword section empty |
| The practice has no keywords on our side | Succeeds with an empty list; no API call cost |
| A keyword is tracked here but not in SEMrush | Row appears with a blank position |
| SEMrush reports the term as not ranking | Position shown as unranked, not as zero |
| The API fails | Warning recorded; keyword section empty; rest of report unaffected |

### Known limits

- **"Potential traffic" and "Growth" are both approximations.** SEMrush exposes no
  dedicated figure for either on this report. Potential traffic uses the closest available
  signal (traffic share for the most recent tracked date); growth is the change in that
  same traffic share across the earliest and latest tracked dates in one response. Treat
  both as indicative, not exact.
- **Growth is nil for a practice's first month or two.** It needs two distinct tracked
  dates in the Position Tracking response, which a newly-added project doesn't have yet.
- **Keyword Difficulty comes from a second, genuinely separate SEMrush call** (not part of
  Position Tracking) and can fail independently — see Failure modes.
- **Only the practice's own domain is measured**, matched by a wildcard pattern built from
  their website address. If the tracking project was set up against a different domain
  form, positions come back empty.

### FAQ

**Q: The keyword table is empty but we know we rank.**
A: Almost always the project ID. Check it is the full `project_campaign` pair, then check
the keywords are actually tracked in that SEMrush project.

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

#### Keyword Difficulty — `GET /` (classic Analytics API, bulk)

| Parameter | Value |
|---|---|
| `key` | API key |
| `type` | `phrase_kdi` |
| `database` | `us` — MSP's practices are all US-based |
| `phrase` | semicolon-joined keyword phrases, up to 100 per request |
| `export_columns` | `Ph,Kd` |

**Response is semicolon-delimited CSV** (the classic Analytics API shape), not JSON:

```
Keyword;Keyword Difficulty Index
cosmetic dentistry;81
```

Confirmed live against MSP's real account (see Field mapping) — a request without
`database` fails with `ERROR 46 :: MANDATORY PARAMETER database NOT SET OR EMPTY`.

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

Rows are matched to `ClientKeyword` records **by downcased phrase**, then written to
`ReportKeywordRanking`.

| Source | Column | Notes |
|---|---|---|
| matched `ClientKeyword#id` | `keyword_id` | Match is case-insensitive |
| `Fi[url_mask]` | `position` | Non-numeric (`"-"`) becomes `nil` |
| `Tr[latest_date][url_mask]` | `potential_traffic` | Latest date, not earliest. Approximation |
| `Tr[latest] - Tr[earliest]` (same response) | `growth` | Nil if only one tracked date exists |
| `Kd` from the bulk KD response | `keyword_difficulty` | Matched by downcased phrase; nil if the KD call fails — see Failure modes |
| *from last month's report* | `previous_position` | Written by `ReportGenerator`, not this adapter |

**Both `growth` and `keyword_difficulty` are written to `ReportKeywordRanking`, not
`ClientKeyword`** — they're per-report-month snapshots like `position`, not a fact about the
keyword that holds forever. `ClientKeyword#keyword_difficulty` still exists in the schema
but is no longer read anywhere; it's seed-data-only legacy from before this adapter fetched
KD live, and is a candidate for removal in a future migration (see Gotchas).

The URL mask is derived from `client.website_url` by stripping scheme, `www.` and any
trailing slash, then wrapping: `*.{domain}/*`.

**Every tracked keyword produces a row**, even one SEMrush did not return — with `nil`
position. The report needs the full tracked set, not only the ranking subset.

### Key files

| Path | Role in this feature |
|---|---|
| `app/services/adapters/semrush_adapter.rb` | The whole integration |
| `app/models/client_keyword.rb` | The tracked terms, and the `active` scope |
| `app/models/report_keyword_ranking.rb` | Per-report position record |
| `app/services/report_generator.rb` | `sync_keywords` — carries `previous_position` forward |
| `app/presenters/report_presenter.rb` | `keyword_movement`, and the gained/held/dropped folds |
| `db/migrate/20260803221106_add_keyword_difficulty_to_report_keyword_rankings.rb` | Adds the per-report KD% column |
| `test/services/adapters/semrush_adapter_test.rb` | Live-shaped JSON, the `"-"` case, the empty-keywords case, growth derivation, KD success/degrade |

### Data

| Model / table | Role |
|---|---|
| `ClientKeyword` | `keyword`, `intent`, `keyword_difficulty` (legacy, unread — see Gotchas), `serp_features`, `active` |
| `ReportKeywordRanking` | `position`, `previous_position`, `potential_traffic`, `growth`, `keyword_difficulty` |

`report_keyword_rankings` is unique on `(report_id, keyword_id)` at the database level.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| Missing `external_id` | `Result.failure("semrush: no project id configured…")` | `error_log` |
| No active keywords | `Result.success(rankings: [])` — **not** a failure | Nothing |
| Position Tracking HTTP error after retries | `Result.failure` — the whole call fails | `error_log` |
| Keyword Difficulty HTTP error | **Degrades independently** — rankings still succeed, `keyword_difficulty` is `nil` for every keyword this run | **Nowhere** |
| Wrong ID form (project only) | SEMrush returns "campaign not found" | `error_log` |

The KD row is worth knowing: unlike Position Tracking, a failed KD call never fails the
report — it's supplementary, not load-bearing, so it silently leaves KD% blank rather than
losing the whole keyword section.

### Gotchas

- **The ID is `project_campaign`, not the project ID.** This is the mistake to check first
  on any empty keyword section.
- **Keyword matching is downcased on both sides.** SEMrush returns lowercase in practice,
  but the test deliberately feeds mixed case to lock that in.
- **`display_limit` is 500** because the report defaults to 10 rows and does not paginate.
  A practice tracking more than 500 terms would silently truncate.
- **`previous_position` never comes from SEMrush.** Do not be tempted by `Be` or a diff
  field — our own month-over-month record is the source of truth, and switching would break
  the gained/held/dropped counts.
- **`potential_traffic` reads the latest date in `Tr`**, not the earliest, and is an
  approximation of a metric SEMrush does not actually expose.
- **A keyword with no previous position is neither gained nor dropped** — see
  `ReportPresenter#keyword_movement`. New keywords must not skew the summary counts.
- **The Keyword Difficulty call is a different base path (`/`) and a different response
  format (semicolon CSV) from Position Tracking (`/reports/v1/...`, JSON).** Don't assume
  the two share a parser.
- **`KD_BATCH_SIZE` (100) exists to keep one request under SEMrush's phrase-count cap** —
  a practice tracking more than 100 keywords issues multiple bulk KD requests, not a
  pagination request.
- **`ClientKeyword#keyword_difficulty` is legacy and unread.** The live value is on
  `ReportKeywordRanking` now; don't reintroduce a read from the old column.

### Not built yet

- No pagination beyond `display_limit: 500` for Position Tracking.
- **`ClientKeyword#serp_features` is still stored and rendered but never populated live** —
  it's seed-data only. SERP feature and intent classification would need a different
  SEMrush endpoint (not researched yet); flag before building against it.
- Dropping the now-unused `client_keywords.keyword_difficulty` column — additive-then-remove
  per CLAUDE.md, not done in the same change that stopped reading it.

---

## Changing this feature

- **Keep producing a row for every tracked keyword**, ranked or not.
- **Keep `previous_position` sourced from our own prior report.**
- **Keep the not-ranked case as `nil`, never `0`** — position 0 would sort as the best
  possible rank.
- **Keep `keyword_difficulty` and `growth` on `ReportKeywordRanking`, not `ClientKeyword`.**
  Both are per-report snapshots — writing them back onto the keyword definition would let a
  later month's value silently rewrite what an earlier report showed.
- **A failed Keyword Difficulty call must keep degrading independently**, never fail the
  whole adapter — it's supplementary, unlike Position Tracking.
