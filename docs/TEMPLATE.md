---
# Copy this file to docs/features/<slug>.md and fill it in. Delete these comments.
#
# Relative links below are written for that destination, not for this file's own
# location — so ../README.md and ../../CLAUDE.md resolve correctly once copied, and
# appear broken while sitting here. Don't "fix" them.
title: Human readable name
slug: kebab-case-matching-the-filename
status: shipped          # shipped | partial | planned
last_verified: YYYY-MM-DD
related: []              # slugs of other documents a reader should follow
---

# {title}

> **Status:** {shipped / partial / planned} · **Last verified:** {date}
>
> One sentence a non-technical reader can understand, describing what this is.

---

## For everyone

Everything under this heading is for the client and for a developer's first day. Plain
language, no file paths, no class names, no term that isn't in the
[glossary](../README.md#glossary).

### Purpose

Why this exists and what problem it solves. Two or three sentences. If you can't explain
it without naming a class, you don't understand it well enough yet.

### Who uses it

Which people or roles touch this, and what each can do. Name real roles — an MSP admin, a
support user, a practice — not database tables.

### How it behaves

The actual experience, as numbered steps: what the person does, what the system does
back. Normal path only; exceptions go in the next section.

1. …
2. …

### When data is missing

**Mandatory.** This system degrades rather than fails: any of five external services can
be unavailable and the report must still render. Spell out, in plain language, what the
client sees in each case.

| What's missing | What the client sees |
|---|---|
| … | … |

If nothing here can be missing, write "Not applicable — no external dependencies" so the
next person knows it was considered rather than skipped.

### FAQ

Real questions someone has asked, or would. This is the future support knowledge base, so
answer the person asking, not the person who built it.

**Q: …**
A: …

---

## For developers

Internal from here down. File paths, classes, columns, and constraints are fine.

### How it works

The technical flow in execution order. Name the layer each step happens in (controller,
service, adapter, presenter, view) so it maps onto
[CLAUDE.md](../../CLAUDE.md#which-layer-owns-it). Describe the shape; don't paste code
that will drift.

### Key files

**This table is how the next agent finds this document** — the update rule in
[README.md](../README.md#keeping-documents-current) works by grepping `docs/` for a
changed path. A missing row means a document that silently rots.

| Path | Role in this feature |
|---|---|
| `app/…` | … |

### Data

Models and tables read or written, and the invariants that must hold. Call out anything
enforced by a database constraint rather than only a validation, and anything
deliberately snapshotted rather than recomputed.

| Model / table | What it holds here |
|---|---|
| … | … |

### Failure modes

What can go wrong, what the user sees, and **where a human would find out**. There is no
error-tracking service, so the answer is usually a domain table
(`report_generation_logs`, `send_logs`) — name it, and say plainly if the answer is
"nowhere yet".

| Failure | User sees | Recorded in |
|---|---|---|
| … | … | … |

### Gotchas

Things that would cost the next person an hour: a wrong assumption that looks right, an
ordering dependency, a name that means something unexpected. If you lost time to it here,
it belongs here.

### Not built yet

Explicit gaps, so nobody assumes absence is a bug or half-reimplements something. Link
the decision if there was one.

---

## Changing this feature

Rules a future change must not break — the ones that came from the client rather than
from the code. Those are the ones that look arbitrary and get "cleaned up" by someone who
doesn't know better.

- …
