---
title: SEMrush integration
slug: integration-semrush
status: shipped
last_verified: 2026-08-02
related: [integrations, monthly-report, report-generation]
---

# SEMrush integration

> **Status:** shipped — endpoint and response shape confirmed live · **Last verified:** 2026-08-02
>
> SEMrush supplies the report's keyword performance section: where each tracked search term
> currently ranks.

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

- **"Potential traffic" is an approximation.** SEMrush exposes no dedicated figure for it
  on this report, so the closest available signal (traffic share for the most recent date)
  is used. Treat it as indicative, not exact.
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

Three things confirmed live that contradict the obvious assumptions:

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
| *from last month's report* | `previous_position` | Written by `ReportGenerator`, not this adapter |

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
| `test/services/adapters/semrush_adapter_test.rb` | Live-shaped JSON, the `"-"` case, the empty-keywords case |

### Data

| Model / table | Role |
|---|---|
| `ClientKeyword` | `keyword`, `intent`, `keyword_difficulty`, `serp_features`, `active` |
| `ReportKeywordRanking` | `position`, `previous_position`, `potential_traffic`, `growth` |

`report_keyword_rankings` is unique on `(report_id, keyword_id)` at the database level.

### Failure modes

| Failure | Result | Recorded in |
|---|---|---|
| Missing `external_id` | `Result.failure("semrush: no project id configured…")` | `error_log` |
| No active keywords | `Result.success(rankings: [])` — **not** a failure | Nothing |
| HTTP error after retries | `Result.failure` | `error_log` |
| Wrong ID form (project only) | SEMrush returns "campaign not found" | `error_log` |

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

### Not built yet

- No pagination beyond `display_limit: 500`.
- `ClientKeyword#keyword_difficulty` and `#serp_features` are stored and rendered but
  **never populated by this adapter** — they are seed-data only today.
- `ReportKeywordRanking#growth` likewise is seeded but never written by generation.

---

## Changing this feature

- **Keep producing a row for every tracked keyword**, ranked or not.
- **Keep `previous_position` sourced from our own prior report.**
- **Keep the not-ranked case as `nil`, never `0`** — position 0 would sort as the best
  possible rank.
