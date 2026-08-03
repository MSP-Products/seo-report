---
title: Design system
slug: design-system
kind: reference
last_verified: 2026-08-03
---

# Design system

The visual vocabulary for every page in this app. **Read this before building or changing
any view** — it is what stops two screens built a month apart looking like two products.

Derived from an audit of what the code actually uses, not invented. Where the codebase is
currently inconsistent, the intended value is stated and the exception is listed under
[Known inconsistencies](#known-inconsistencies).

**Tailwind v4, no component CSS layer.** Everything is utility classes in ERB. There is no
`.btn` class to reach for — reuse comes from **extracting a partial**, not from writing CSS.

---

## Colour

### Brand tokens

Defined in `app/assets/tailwind/application.css` under `@theme`. These four are the only
custom colours; everything else is stock Tailwind.

| Token | Hex | Use |
|---|---|---|
| `teal-primary` | `#0d9488` | Primary buttons, active nav, brand mark, progress fills |
| `teal-dark` | `#0f766e` | Links, primary hover, icon glyphs on light tint |
| `cyan-primary` | `#06b6d4` | Gradient partner to teal. Not used alone |
| `cyan-light` | `#22d3ee` | Gradient extension |

**Green is an accent, not a theme.** This is a neutral app with a teal accent — the
dominant colour on any screen should be slate and white. If a screen looks green, it is
wrong.

### Semantic palette

| Role | Colour | Typical use |
|---|---|---|
| **Neutral** | `slate` | Everything structural. See the ramp below |
| **Positive** | `emerald` | Success, upward movement, healthy status |
| **Warning** | `amber` | Expiring, degraded, needs attention |
| **Danger** | `red` | Failure, destructive actions, errors |
| **Informational** | `cyan` | Neutral callouts, first-report badge |
| **AI SEO** | `violet` | The AI visibility surfaces only — this is its signature colour |
| **In progress** | `teal` (tint) | An active/generating state — `bg-teal-primary/10 text-teal-dark`. The one place teal itself, not emerald, means "this is fine" |

### The slate ramp

Use these exact steps. They cover every structural need.

| Step | Use |
|---|---|
| `slate-50` | Page background, table row hover, subtle fills |
| `slate-100` | Track backgrounds behind progress bars |
| `slate-200` | **Every border.** Card, divider, input |
| `slate-300` | Disabled borders, dashed placeholder borders |
| `slate-400` | Icons in a muted context. **Never body text** |
| `slate-500` | Secondary text, captions, labels |
| `slate-600` | Body copy |
| `slate-700` | Emphasised body |
| `slate-900` | Headings and primary values |

`slate-300` and `slate-400` fail contrast for body text. Keep them for borders, disabled
states and decorative icons.

### Tints

A `/10` tint on the brand colour is the standard soft fill: `bg-teal-primary/10` with
`text-teal-dark` on top. Used for icon badges, avatar circles and the active nav item.

For status pills use the colour's `-50` background with its `-700` text:
`bg-emerald-50 text-emerald-700`, `bg-red-50 text-red-700`, `bg-amber-50 text-amber-700`.

### Gradients

Reserved for the **public report hero only**. Do not introduce gradients into the admin
panel.

```
bg-gradient-to-br from-teal-primary to-cyan-primary
bg-gradient-to-br from-teal-dark via-teal-primary to-cyan-primary
```

---

## Typography

Inter, loaded from Google Fonts. One family, no exceptions.

**This is a compact, data-dense interface.** `text-sm` and `text-xs` carry almost
everything — 87 of 106 sizing utilities in the codebase. Do not inflate it.

| Role | Classes | Use |
|---|---|---|
| Report hero | `text-4xl sm:text-5xl font-semibold tracking-tight` | Public report only |
| Page title | `text-2xl font-semibold tracking-tight text-slate-900` | Every admin page `h1` |
| Section title | `text-xl font-semibold text-slate-900` | Major section headings |
| Stat value | `text-3xl font-semibold tracking-tight text-slate-900` | The big number on a metric card |
| Card title | `text-sm font-medium text-slate-900` | Card and list-row headings |
| Body | `text-sm text-slate-600` | Paragraphs, descriptions |
| Secondary | `text-sm text-slate-500` | Supporting text, subtitles |
| Caption | `text-xs text-slate-500` | Metadata, timestamps, helper text |
| Eyebrow | `text-xs font-semibold uppercase tracking-wider` | Section labels above a title |

**Three weights only:** `font-medium` (labels, buttons, emphasis), `font-semibold`
(headings, values), `font-bold` (reserved — brand mark and the report's hero stat).

`tracking-tight` on `text-2xl` and larger. `tracking-wider` on uppercase eyebrows. Nothing
else gets tracking.

---

## Shape

### Radius — a four-step ladder

| Class | Use |
|---|---|
| `rounded-full` | Pills, badges, status dots, avatars, progress bars |
| `rounded-2xl` | **Cards.** The primary surface |
| `rounded-xl` | Tiles nested inside a card, callout boxes |
| `rounded-lg` | Interactive controls — buttons, inputs, icon badges |

Bare `rounded` and `rounded-md` are strays. Do not add more.

### Elevation

**`shadow-sm` is the default and usually the only one you need.** Cards are defined by
their border, not their shadow.

`shadow-lg` is reserved for genuinely floating elements — the report's month-switcher
panel. Nothing in the admin panel should exceed `shadow-sm`.

### Spacing

Card padding `p-5` (compact) or `p-6` (roomy). Page sections separated by `space-y-10`,
cards within a grid by `gap-4`. Form fields `space-y-5`, label to input `gap-2`.

---

## Components

These are the patterns already in the codebase. **Reuse by extracting a partial**, never by
duplicating markup.

### Card — the primary surface

```
rounded-2xl border border-slate-200 bg-white p-5 shadow-sm
```

### Page header

Every admin page opens the same way:

```erb
<div class="mb-6">
  <h1 class="text-2xl font-semibold tracking-tight text-slate-900">Title</h1>
  <p class="mt-1 text-sm text-slate-500">One line explaining the page.</p>
</div>
```

A detail page adds a back link above the title: `text-sm text-slate-500 hover:text-slate-700`.

### Buttons

| Kind | Classes |
|---|---|
| Primary | `rounded-lg bg-teal-primary px-4 py-2 text-sm font-medium text-white hover:bg-teal-dark` |
| Secondary | `rounded-lg border border-slate-200 bg-white px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50` |
| Danger | `rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700` |
| Text/cancel | `text-sm text-slate-500 hover:text-slate-700` |
| Inline link | `text-sm font-medium text-teal-dark hover:underline` |

### Status dot

A `size-2 rounded-full` element, coloured by state: `bg-emerald-500` healthy,
`bg-amber-500` warning, `bg-red-500` failed, `bg-slate-300` unknown or not configured.

The colour is always paired with a text label — **never convey status by colour alone.**

### Status pill

```
inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium
```
plus the semantic pair, e.g. `bg-emerald-50 text-emerald-700`.

### Icon badge

`size-9` (or `size-8`) `rounded-lg` square, `bg-teal-primary/10` with `text-teal-dark`,
centring an icon. Rendered by the `icon_badge` helper — do not hand-roll it.

### Progress bar

A determinate bar for a real, computable fraction (e.g. reports ready / total expected) —
never a decorative animation.

```erb
<div class="h-1.5 w-full overflow-hidden rounded-full bg-slate-100">
  <div class="h-full rounded-full bg-teal-primary" style="width: <%= percent %>%"></div>
</div>
```

Track is `slate-100`, fill is solid `teal-primary`. Introduced on the Dashboard's
generating-run card.

### Loading spinner

A small inline spinner for "this is actively happening right now" — paired with a text
label (`Generating`), never used alone as the only signal.

```erb
<span class="size-4 animate-spin rounded-full border-2 border-teal-primary/25 border-t-teal-primary" aria-hidden="true"></span>
```

`aria-hidden` because the adjacent label already carries the meaning for a screen reader.

### Form field

Use the `shared/_form_group` partial. It handles label, input, textarea, password toggle and
error state. Input styling lives there; do not restyle inputs inline.

### Empty state

Dashed border, centred, muted:
```
rounded-xl border border-dashed border-slate-300 p-4 text-sm text-slate-600
```

### Flash alert

Use `shared/_alert`. It carries `role="alert"` and the success/error variants.

---

## Layout

**Admin:** fixed `w-60` sidebar, white with a `border-r border-slate-200`, against a
`bg-slate-50` page. Content in `main` with `p-8`. Active nav item is
`bg-teal-primary/10 font-medium text-teal-dark`; inactive is `text-slate-600
hover:bg-slate-50`.

**Public report:** centred `max-w-4xl` column, `px-4 sm:px-6`, sections `space-y-10`.

**Grids:** `grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3` for cards; metric rows use
`md:grid-cols-3`.

Admin is desktop-first but must not break on a tablet. The public report is phone-first —
that is how practices read it.

---

## Rules

1. **Use the tokens.** Never a raw hex in a view. If you need a colour that isn't here, it
   probably belongs in `@theme` — or you don't need it.
2. **Never build a class name by interpolation.** Tailwind only compiles classes it can find
   as literal text in source, so `bg-#{colour}-500` silently produces no CSS. Map to
   complete literal strings, as `AgencyConnection::DISPLAY` does.
3. **No inline SVG in views.** Icons go through `report_icon` / `icon_badge`. A new icon
   means a new entry in `ICON_INNER`, matched to Lucide.
4. **Extract a partial when markup repeats.** There is no component CSS layer, so a partial
   is the unit of reuse. `_stat_card` and `_section_card` are the established examples.
5. **Declare strict locals** in every partial: `<%# locals: report (ReportPresenter) %>`.
6. **Never convey meaning by colour alone** — always pair with text or an icon.
7. **Design the empty and failure states.** A new install has no practices, no reports and
   no credentials, and that is the first thing anyone sees.
8. **No dark mode.** It does not exist here. Do not add `dark:` variants.

---

## Known inconsistencies

Real drift found in the audit. **Fix these when you touch the file**, do not sweep them
separately.

| Issue | Where | Intended |
|---|---|---|
| `gray-*` used instead of `slate-*` | `shared/_form_group.html.erb`, `shared/_login_header.html.erb`, `layouts/application.html.erb` | `slate-*` everywhere |
| `green-*` used instead of `emerald-*` | `shared/_alert.html.erb` | `emerald-*` |
| Bare `rounded` and `rounded-md` | Scattered | The four-step ladder above |
| `shadow-md` / `shadow-xl` one-offs | Scattered | `shadow-sm`, or `shadow-lg` if genuinely floating |

The `gray`/`slate` split is the one that shows: the login form's inputs are a visibly
different neutral from every other surface.

---

## Not built yet

- **No dark mode**, and none planned.
- **No component CSS layer.** Deliberate at this size — revisit only if partial extraction
  stops being enough.
- **No documented focus-visible treatment.** Inputs have a focus ring
  (`focus:ring-3 focus:ring-teal-600/15`); buttons and links rely on browser defaults. Worth
  defining before an accessibility pass.
- **No skeleton states.** The Dashboard has a real progress bar and spinner for an
  in-progress generation run (see Progress bar / Loading spinner above), but nothing in the
  admin panel shows a skeleton while a page's own data is loading.
