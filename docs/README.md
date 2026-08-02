# Documentation

Documentation for **My Social Practice — SEO Reports**.

| Document | For | Covers |
|---|---|---|
| **[MSP-GUIDE.md](MSP-GUIDE.md)** | MSP staff | How to actually run the system: onboarding a client, generating a report, fixing a failure |
| **[TEMPLATE.md](TEMPLATE.md)** | Developers | The shape every feature document must follow |
| **[../CLAUDE.md](../CLAUDE.md)** | Developers | How to *write* code here — craft, structure, testing |
| **[../CONVENTIONS.md](../CONVENTIONS.md)** | Developers | The Rails rulebook — framework mechanics |

### Feature documents

What the system does, one document per capability.

| Document | Covers |
|---|---|
| [monthly-report](features/monthly-report.md) | The public report page — the deliverable |
| [report-generation](features/report-generation.md) | The monthly process that produces a report |
| [page-scan](features/page-scan.md) | The nightly site scan behind "Pages published" |
| [admin-panel](features/admin-panel.md) | Login, roles, and the Connections page |
| [integrations](features/integrations.md) | **The adapter layer** — shared contract, credentials, retries |
| [integration-yext](features/integration-yext.md) | Citations, AI visibility, Google Business Profile |
| [integration-semrush](features/integration-semrush.md) | Keyword rankings |
| [integration-google-analytics](features/integration-google-analytics.md) | Website traffic |
| [integration-hubspot](features/integration-hubspot.md) | Practice details, AI SEO enrolment |
| [integration-ghl](features/integration-ghl.md) | Appointments and revenue |
| [integration-anthropic](features/integration-anthropic.md) | The written highlight banners |

**Status and `last_verified` live in each document's frontmatter, deliberately not here.**
Duplicating them would mean every branch that documents anything rewrites this table — see
[resolving conflicts](#resolving-conflicts).

Integration documents are **prefix-grouped, not nested**, so they sort together in any file
listing — the same reasoning that keeps `report_*` models flat (see
[CLAUDE.md](../CLAUDE.md#project-structure)).

### Reference documents

Cross-cutting facts that belong to no single feature. These do **not** follow
`TEMPLATE.md` — there is no user-facing half to a schema.

| Document | Covers |
|---|---|
| [data-model](reference/data-model.md) | All 22 tables, columns, constraints, and which columns are never written |
| [configuration](reference/configuration.md) | Environment variables, credentials, initializers, deployment |
| [jobs-and-schedules](reference/jobs-and-schedules.md) | What runs in the background, when, and what happens when it doesn't |

---

## What this system is

An internal tool that produces a monthly SEO report for each dental practice MSP works
with. It pulls each practice's data from five external services, stores a frozen
snapshot per month, and publishes it as a private web page the practice opens from a
link.

```
HubSpot ─┐                                            ┌─ practice details, AI SEO enrolment
GHL ─────┤                                            ├─ appointments, revenue
Yext ────┼──▶  ReportGenerator  ──▶  frozen snapshot  ┼─ citations, AI visibility, GBP
SEMrush ─┤       (one practice,       (Report* rows)  ├─ keyword rankings
GA4 ─────┘        one month)                          └─ traffic

           SitemapScanner  ──▶  SitemapPage  ─────────── pages published
            (nightly, per practice)                              │
                                                                 ▼
                                        ReportPresenter ──▶ /reports/<token>
```

Two surfaces, and only two:

- **The public report** — `/reports/<token>`, no login, one page per practice per month.
  This is the deliverable.
- **The admin panel** — login required, currently one working page (Connections).
  Everything else MSP needs to do is a console or rake command today; see
  [MSP-GUIDE.md](MSP-GUIDE.md).

### Where the project actually stands

Honest status, so nobody assumes a gap is a bug:

**Working end to end:** report rendering with every degraded state, report generation
(idempotent and re-runnable), the nightly page scan, agency-wide credential management,
and login with two roles.

**Verified against live APIs:** Yext, SEMrush, Google Analytics.
**Not yet verified:** HubSpot and GoHighLevel — HubSpot's custom property names are still
a placeholder convention.

**The significant gaps**, each documented in the relevant feature doc under *Not built
yet*:

- **Nothing schedules report generation**, and nothing alerts when one fails or is never
  run.
- **No Clients page** — adding a practice, linking it to a service, and managing keywords
  are console or rake tasks.
- **No Dashboard page** — generation health is recorded in the database but surfaced
  nowhere.
- **No emailing.** `SendLog` and `emailed_at` exist; no mailer does.
- **Credential health labels are never set automatically.**

---

## The documentation convention

### One document per feature, split by audience

Every feature document follows [TEMPLATE.md](TEMPLATE.md) and is cut in half by a fixed
line:

- **For everyone** — Purpose · Who uses it · How it behaves · When data is missing · FAQ.
  Plain language. No file paths, no class names. Safe to hand a client as-is.
- **For developers** — How it works · Key files · Data · Failure modes · Gotchas · Not
  built yet.

The split exists because this system has two readers who will never merge: the client
who paid for it, and the developer who inherits it. Writing separate document sets for
them guarantees the two drift apart; writing one document with a hard line does not.

**"When data is missing" is mandatory**, not optional. Five integrations can each be
absent and the report still has to render. That degraded behaviour is the single thing
clients ask about most, so it gets a table, not a footnote.

### Two genres

Not everything is a feature. A database schema has no user-facing half, and forcing one
produces padding.

| Genre | For | Follows the template? |
|---|---|---|
| `features/` | A user-visible capability or an external integration | **Yes** |
| `reference/` | Cross-cutting facts — schema, configuration, scheduling | No |

**A feature earns a document** when it is a user-visible capability or an external
integration. Internal refactors do not get one.

**A reference document earns its place** when a fact is needed by several features and
belongs to none — the data model, the environment variables, what runs on a schedule. If
it only matters to one feature, it goes in that feature's document instead.

### File layout

```
docs/
├── README.md           this file — the convention, the index, the glossary
├── TEMPLATE.md         the shape every feature document copies
├── MSP-GUIDE.md        task-based guide for MSP staff
├── features/
│   ├── <slug>.md               one per capability
│   └── integration-<service>.md  one per external service, prefix-grouped
└── reference/
    └── <slug>.md       cross-cutting facts; no template
```

**Integrations get one document each**, prefix-grouped rather than nested in a
subdirectory, so they sort together in a flat listing. `features/integrations.md` covers
only what they share — the adapter contract, credential resolution, the HTTP policy.
Per-service detail (endpoints, request shapes, field-to-column mappings, response quirks)
belongs in that service's own document.

### Keeping documents current

**A change that alters behaviour is not finished until its document is updated.** A
document that lies is worse than no document, because the next person trusts it.

**Finding the right document:** every feature document carries a **Key files** table.
Grep this directory for the path you edited:

```bash
grep -rl "app/services/report_generator.rb" docs/
```

No match means either the file isn't feature-level (fine), or a **Key files** table is
missing a row — add it. That table is what makes the whole scheme work, so it is the one
section that must never go stale.

**What to update:**

| You changed | Update |
|---|---|
| What a user sees or can do | **How it behaves**, and **When data is missing** if a degraded state moved |
| An external integration's behaviour | **When data is missing**, **Failure modes** |
| The flow through the layers | **How it works** |
| Which files implement it | **Key files** |
| A model, column, or constraint | **Data** |
| A business rule that came from the client | **Changing this feature** |
| Something that cost you an hour to work out | **Gotchas** |
| How MSP performs a task | **[MSP-GUIDE.md](MSP-GUIDE.md)** |

Then bump `last_verified` in the frontmatter — **only** if you actually re-read the
document against the code. It is a claim that the document was true on that date, not a
timestamp of your last edit.

### Adding a document

1. Copy `TEMPLATE.md` to `docs/features/<slug>.md`.
2. Fill in every section. If one genuinely doesn't apply, write "Not applicable" and why
   — an empty section reads as an oversight, a stated "not applicable" reads as a
   decision.
3. Add a row to the index in this file.

### Checking the documentation

`lib/tasks/docs.rake` verifies the three promises this convention makes. No Rails
environment, no database — it runs in a second.

```bash
bin/rails docs:check        # all three
bin/rails docs:coverage     # source files not named in any document
bin/rails docs:links        # links and anchors that point nowhere
bin/rails docs:paths        # Key files entries whose path no longer exists
```

`docs:paths` is the one that matters most: the "grep `docs/` for the file you changed" rule
is only true while those tables are accurate, so a renamed file silently breaks the lookup
until this catches it.

`docs:coverage` carries an allow-list of stock Rails files. **Add to it only for genuinely
untouched framework scaffolding** — if you find yourself exempting something you wrote,
write the document instead.

### Write it down when you learn it

Behaviour changes are the obvious trigger. The less obvious one is **learning something the
document doesn't already say** — and that is where documentation actually compounds. Add it
before you finish, not later:

- **Someone corrects you** on how something should work. Capture the rule *and the why* —
  the why is what stops it being re-litigated.
- **You dig through code or git history** to work out how something behaves. Record the
  answer so the next person skips the hunt.
- **You fix a bug whose root cause was a missing rule.** That belongs in **Gotchas** — it is
  the highest-value section in any document.
- **An external API behaves differently from its documentation.** Write what it *actually*
  does. Every quirk in the integration documents was discovered this way and would otherwise
  be rediscovered at the same cost.

**The bar:** would this note save the next person from making the same wrong choice? If yes,
write it. Exact endpoints, field names, file paths and constraints are gold. Vague
observations ("this is a bit confusing") are not.

### Resolving conflicts

Living documentation conflicts differently from code, and more often — because two branches
can legitimately need to change the same paragraph. Three things keep it manageable.

**1. The structure already limits the blast radius.**

- **One document per feature** means two branches only collide when they touch the same
  feature. Splitting per-service integration documents out of one shared file was partly
  for this reason.
- **Status and `last_verified` are not in the index.** They live in each document's
  frontmatter, so a branch documenting one feature never touches a shared table. This is the
  single biggest source of avoidable conflict, and it is designed out rather than resolved.
- **Append to tables; never reorder them.** Reordering rewrites every line and turns a
  one-row addition into a whole-table conflict.

**2. Default to keeping both sides.**

Unlike code, a documentation conflict is usually two people describing two different true
things — not two competing implementations. **Union is the right first move**, then read the
merged section as a whole.

Naive union has two failure modes, so check for both:

- **Duplication** — the same fact stated twice in different words. Merge them into one.
- **Contradiction** — two branches describing the same behaviour differently. That means the
  behaviour changed under one of them. **Go read the code**; do not pick the more
  confident-sounding sentence.

**3. After resolving, re-verify and re-date.**

`last_verified` is a claim that the document was true on that date. Once you have merged two
edits, **neither original date describes the merged text** — nobody has ever read it in that
form. So:

- Re-read the merged sections against the current code.
- Set `last_verified` to today.
- If you cannot verify it now, **lower `status`** rather than leaving a date you cannot
  stand behind.

Merging two `last_verified` values by taking the later one is the wrong instinct: it claims
verification that never happened.

**Conflicts that mean something is wrong**

- **Two branches editing the same feature's "How it behaves"** — usually a sign the two
  changes should have been one, or that they conflict in the product as well as the text.
  Resolve the product question first.
- **Repeated conflicts in `data-model.md` or `configuration.md`** — reference documents are
  shared by everything, so they collide most. If it becomes constant, that is a signal the
  document is doing too much and should be split, not that the process is broken.

### House rules

- **Describe behaviour, not implementation, above the developer line.** "The report shows
  a question mark when the practice has no scheduler" — not "`ghl_data_status` is
  `not_connected`".
- **Don't paste code.** Code drifts; the doc won't be updated with it. Name the file and
  describe the shape.
- **Link, don't duplicate.** If CLAUDE.md or CONVENTIONS.md says it, link there. The same
  rule stated twice becomes two rules that disagree.
- **Write the gaps down.** "Not built yet" is documentation. Silence gets reimplemented.
- **Sentence case for headings.** No em-dashes in UI strings quoted from the app.

---

## Glossary

Terms used across these documents and in the report itself.

| Term | Meaning |
|---|---|
| **Practice** | A dental practice — MSP's client. A `Client` in the code. |
| **Report month** | The calendar month a report covers. Always a completed month. |
| **First report** | A practice's first month, showing setup work instead of comparisons. |
| **Access token** | The random code in a report URL. It is the only thing protecting the report. |
| **GBP** | Google Business Profile — the practice's Google listing, with reviews, posts, and photos. |
| **Citations** | Appearances of the practice across online directories, and the actions people took on them. |
| **AI visibility** | How often and how favourably the practice appears in AI assistants (ChatGPT, Gemini, Perplexity, Google's AI answers). |
| **Keyword position** | Where the practice ranks in search results for a tracked term. Lower is better; 1 is top. |
| **Keyword difficulty** | How hard a term is to rank for, 0–100. Higher is harder. |
| **Search intent** | Why someone searched: Commercial, Transactional, Informational, Navigational. |
| **Agency-wide credential** | One API key MSP holds that works for every practice. |
| **External ID** | A practice's identifier inside a third-party service — different in each one. |
| **Adapter** | The code that talks to one external service. |
| **Degraded section** | A report section showing a placeholder because its data source was unavailable. |
