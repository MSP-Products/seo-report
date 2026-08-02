# Documentation

Documentation for **My Social Practice — SEO Reports**.

| Document | For | Covers |
|---|---|---|
| **[MSP-GUIDE.md](MSP-GUIDE.md)** | MSP staff | How to actually run the system: onboarding a client, generating a report, fixing a failure |
| **[TEMPLATE.md](TEMPLATE.md)** | Developers | The shape every feature document must follow |
| **[../CLAUDE.md](../CLAUDE.md)** | Developers | How to *write* code here — craft, structure, testing |
| **[../CONVENTIONS.md](../CONVENTIONS.md)** | Developers | The Rails rulebook — framework mechanics |

`docs/features/` is where per-feature documents live. **It is empty right now.** This
branch establishes the convention; the feature documents get written against it next.

---

## What this system is

An internal tool that produces a monthly SEO report for each dental practice MSP works
with. It pulls each practice's data from five external services, stores a frozen
snapshot per month, and publishes it as a private web page the practice opens from a
link.

Two surfaces, and only two:

- **The public report** — `/reports/<token>`, no login, one page per practice per month.
  This is the deliverable.
- **The admin panel** — login required, currently one working page (Connections).
  Everything else MSP needs to do is a console or rake command today; see
  [MSP-GUIDE.md](MSP-GUIDE.md).

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

### File layout

```
docs/
├── README.md           this file — the convention and the index
├── TEMPLATE.md         the shape to copy
├── MSP-GUIDE.md        task-based guide for MSP staff
└── features/
    └── <slug>.md       one per feature
```

A feature earns a document when it is **a user-visible capability or an external
integration**. Internal refactors do not get one.

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
