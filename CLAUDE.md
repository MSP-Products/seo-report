# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repository.

## Division of labour with CONVENTIONS.md

**[CONVENTIONS.md](CONVENTIONS.md) is the Rails rulebook — read the relevant section before you
write code.** It covers the framework mechanics in 26 numbered sections: naming, migrations,
model structure, validations, associations, callbacks, querying, controllers, routing, views,
Hotwire, Propshaft/importmap, jobs, mailers, services, Zeitwerk, testing, security, caching,
logging, credentials, file structure, git, and the project's business rules.

**This file is the craft layer on top of it:** how to shape code so it stays readable,
simple, and scalable. When the two overlap, CONVENTIONS.md wins on mechanics; this file wins
on structure and naming. Neither is optional.

Do not duplicate CONVENTIONS.md content here. If you learn a durable *mechanical* rule, add it
there; a durable *craft* rule, add it here.

**[docs/](docs/) answers a third question — what the system *does*, not how to write Rails.**
`docs/README.md` holds the documentation convention, `docs/TEMPLATE.md` the shape every feature
document follows, and `docs/MSP-GUIDE.md` how MSP staff operate the system.

---

## Updating the documentation

**A change that alters behaviour is not finished until its document is updated.** This is part of
Done, not a follow-up. A document that lies is worse than none, because the next person trusts it.

### When to write it — wait for the scope to close, then ask

**Documentation is part of Done for the *branch*, not for each commit.** Write it once the
branch's scope is complete and the code has stopped moving.

**Then ask the user before starting.** Do not begin a documentation pass unprompted — confirm the
scope is actually closed and that they want it written now. They may have another change coming,
may want it in a separate branch, or may not want it yet at all.

Why this rule exists, concretely: documentation was once written for an adapter that was being
rebuilt on another branch at the same time. The result described endpoints that no longer existed
by the time it was committed, and had to be researched and rewritten twice. **Documenting code
that is still in flux produces documentation that is wrong on arrival** — and wrong documentation
is worse than none.

**Capture immediately, write at the end.** These are different things and only one of them
waits. The moment you learn something a document doesn't say — an API behaving unlike its
documentation, a constraint you had to dig out of git history, the root cause of a bug — write
the *note* down straight away, in the branch, wherever it will not be lost. What waits is the
prose describing behaviour that is still changing. Losing hard-won knowledge is a worse failure
than documenting slightly late; the trigger list is in
[docs/README.md](docs/README.md#write-it-down-when-you-learn-it).

So:

- **Mid-branch:** capture facts as you learn them; don't write the narrative sections yet.
- **Scope complete:** ask whether to document now, then read the *current* code — not what you
  remember writing earlier in the session — and write it.
- **Unmerged branches change the answer.** If another branch is rewriting what you are about to
  document, say so and ask whether to wait for it to merge. Documenting against three unmerged
  branches is how a document becomes stale before it is reviewed.

**Which branch the documentation goes on depends on what it is:**

- **Documenting a change you are making → the same branch and the same PR as the code.** This is
  the normal case, and the default. The document and the behaviour it describes must land
  together or they are immediately inconsistent, and a reviewer needs to see both to judge
  either. Do not open a follow-up PR "to document it" — that is the punt this rule exists to
  prevent.
- **A documentation-only effort → its own branch.** Retrofitting documentation onto code that
  was never documented, restructuring the document set, or changing the convention itself
  belongs to no single code change and has nothing to be atomic with. Such a branch should
  contain no code beyond documentation tooling.

The distinction is whether there is a code change for the documentation to be consistent *with*.
If there is, they travel together.

### What to update

**Find the affected document by grepping for the file you changed** — every feature document
carries a Key files table naming its paths:

```bash
grep -rl "app/services/report_generator.rb" docs/
```

No match means either the file isn't feature-level (fine, not everything needs a document), or a
Key files table is missing a row — add it.

| You changed | Update |
|---|---|
| What a user sees or can do | The feature doc's **How it behaves** |
| How a missing integration degrades | **When data is missing** *and* `MSP-GUIDE.md`'s equivalent table |
| An external integration's behaviour | **Failure modes**, and the ID/setup steps in `MSP-GUIDE.md` |
| Which files implement a feature | **Key files** — this is what keeps the doc findable |
| A model, column, or constraint | **Data** |
| How MSP performs any task | **[docs/MSP-GUIDE.md](docs/MSP-GUIDE.md)** |
| A business rule that came from the client | **Changing this feature** |

Then bump `last_verified` — but **only** if you re-read the document against the code. It is a
claim the document was true that day, not a timestamp of your edit.

**Merge conflicts in documentation resolve differently from code:** default to keeping both
sides, then read the merged section for duplication or contradiction, then re-verify against the
code and set `last_verified` to today — because once two edits are merged, neither original date
describes the text anyone has actually read. Full rules in
[docs/README.md](docs/README.md#resolving-conflicts).

Two rules that keep these usable: **describe behaviour, not implementation, above the developer
line** in a feature doc; and **`MSP-GUIDE.md` must stay honest about what needs a developer.**
Most admin tasks are console or rake commands today — if you build UI that replaces one, move it
out of the "Needs a developer" section in the same change.

---

## The project in one paragraph

**My Social Practice — SEO Reports.** A Rails app that pulls monthly SEO data for dental
practice clients from external services and renders a client-facing monthly report. Two
surfaces only:

1. **Public report** — `GET /reports/:access_token` ([reports_controller.rb](app/controllers/reports_controller.rb)),
   unauthenticated, keyed by an unguessable token, `noindex`, `layout "report"`. This is the
   product's deliverable and it is read mostly on phones.
2. **Admin panel** — session-authenticated, sidebar shell in
   [layouts/application.html.erb](app/views/layouts/application.html.erb). Only **Connections**
   (agency-wide API credentials) is built; Dashboard and Clients are stubs that route to
   Connections so nothing 404s.

Stack: Rails 8.1.2 · Ruby 3.3.7 · PostgreSQL 16 · UUID primary keys · Propshaft · Importmap ·
Hotwire (Turbo + Stimulus) · Tailwind v4 (`tailwindcss-rails`) · Solid Queue/Cache/Cable ·
Kamal · `discard` for soft deletes · Minitest. No Node build step. No dark mode today.

Data flows one way: **Adapters** (HubSpot, GHL, Yext, SEMrush, Google Analytics) →
**ReportGenerator** → `Report*` rows → **ReportPresenter** → report partials.

---

## Commands

```bash
bin/setup            # install deps, prepare DB
bin/dev              # dev server (Rails + Tailwind watcher)
bin/ci               # full gate: rubocop, bundler-audit, importmap audit, brakeman, tests, seeds
bin/rails test       # Minitest
bin/rubocop -a       # autocorrect style (rubocop-rails-omakase)
bin/jobs             # Solid Queue worker
```

Always `bin/rails`, never bare `rails`. **`bin/ci` is the gate — run it before you claim
done.** It is the same script CI runs ([config/ci.rb](config/ci.rb)).

---

## Project structure

### Find it fast

Start from what you want to change, not from the tree.

| I want to change… | Go to |
|---|---|
| What a report **looks like** | `app/views/reports/` |
| What a report **says** (a computed number, a label, a percentage) | `app/presenters/report_presenter.rb` |
| Where a report's **data comes from** | `app/services/adapters/<service>_adapter.rb` |
| How a report **gets built** | `app/services/report_generator.rb` |
| The **AI summary copy** | `app/services/highlight_generator.rb` |
| A **column, validation, enum, or scope** | `app/models/<model>.rb` + a new migration |
| A **URL** | `config/routes.rb` |
| **Who can do what** | `app/controllers/concerns/` (auth), `AdminUser#admin?` |
| An **icon** | `ICON_INNER` in `app/helpers/reports_helper.rb` |
| A **colour, font, or token** | `app/assets/tailwind/application.css` |
| **Admin chrome** (sidebar, nav) | `app/views/shared/_admin_sidebar.html.erb` |
| **Scheduling / retries** | `app/jobs/`, `config/recurring.yml` |
| An **API credential's fields or labels** | `AgencyConnection::CREDENTIAL_FIELDS` / `::DISPLAY` |

### The tree

Rails defaults unless marked. `*` = ours, not generated by Rails.

```
app/
├── assets/
│   ├── builds/              gitignored — Tailwind output, built at deploy
│   ├── images/
│   ├── stylesheets/         Propshaft manifest only
│   └── tailwind/
│       └── application.css  @theme design tokens ← all colour/font lives here
├── controllers/
│   ├── concerns/            loading, guarding, strong params, auth
│   └── *_controller.rb      actions only, no private methods
├── helpers/                 markup-producing view utilities only
├── javascript/controllers/  Stimulus, one file per behaviour
├── jobs/                    thin wrappers over services
├── models/
│   ├── concerns/
│   └── *.rb                 flat, prefix-grouped (see below)
├── presenters/            * one per view context; keeps ERB dumb
├── services/              * business operations, #call
│   └── adapters/          * one file per external API, returns Result
└── views/
    ├── layouts/             application (admin) · report (public) · auth · mailer
    ├── reports/             the public deliverable
    ├── connections/         admin
    ├── sessions/            auth
    └── shared/              partials with 2+ consumers, nothing else
```

### Grouping rules

**1. Models stay flat and prefix-grouped — never namespaced.** There are 20 models and 9 begin
with `report_`, so alphabetical sorting already clusters them: `report_ai_visibility`,
`report_citation`, `report_gbp_summary`, `report_traffic`, and so on sit together in any file
list. Namespacing them under `Report::` would rename the classes *and* the tables and buy nothing
— prefix-grouping gives the same findability for free. CONVENTIONS.md §24 allows one level of
nesting; we don't use it. **A new report-section model must carry the `report_` prefix.**

**2. One subdirectory per external boundary.** `app/services/adapters/` exists because there are
five external APIs with a shared contract. Create a subdirectory when a family has 3+ members and
a shared base class; keep single services flat in `app/services/`.

**3. A partial lives with its only consumer; it earns `shared/` on the second one.** Right now
`_alert` (2 consumers) and `_form_group` (2 consumers) belong in `shared/`; `_login_header` has
exactly one consumer (`sessions/new`) and belongs in `app/views/sessions/`. Same rule-of-three
discipline as the rest of this file: don't promote on speculation.

**4. Report view sections get their own directory.** `app/views/reports/` currently mixes two
kinds of file at one level: eight content **sections** (`_traffic`, `_citations`,
`_ai_visibility`, `_keyword_performance`, `_gbp_activity`, `_pages_published`, `_highlights`,
`_first_report_intro`) and the **chrome/primitives** they're built from (`_header`, `_footer`,
`_stat_card`, `_section_card`, `_partnership_cta`). Move the sections to
`app/views/reports/sections/` so `show.html.erb`'s render list maps 1:1 to a directory and the
reusable primitives stand apart. Do it when you next touch that directory.

**5. Tests mirror `app/` exactly.** `app/services/adapters/yext_adapter.rb` →
`test/services/adapters/yext_adapter_test.rb`. No other layout.

**6. One concept, one directory.** See [Vocabulary](#vocabulary-one-word-per-concept) — no
parallel `app/actions/`, `app/operations/`, or `app/interactors/`.

### Divergences and cruft to know about

- **CONVENTIONS.md §24's tree omits `app/presenters/`** — it lists `app/validators/` (which
  doesn't exist) but not presenters (which do, and are load-bearing for the report). This file's
  tree is the current truth; fix §24 when you're next editing it.
- **`app/views/pwa/`** holds a `manifest.json.erb` and `service-worker.js`, but the routes that
  serve them are commented out in `config/routes.rb`. Either wire them up or drop them; don't
  leave a third state.

---

## Unit-level functions — the naming test

**A method is a unit function only if its name accounts for everything it does. If the name
can't cover the whole body, the method is doing too much — split it.**

Apply the test literally:

- **Can you name it without "and", "then", "or"?** If the honest name is
  `sync_summary_and_posts_and_reviews`, that's three methods.
- **Does it need a comment explaining *what* it does?** Then the name failed. Comments are for
  *why* (see [Comments](#comments-explain-why-never-what)); needing a *what* comment is a
  naming smell.
- **Is the body all at one level of abstraction?** A method that both orchestrates
  (`sync_citations(report, data)`) and computes details (`reviews.count { |r| r[:rating] >= 4 }`)
  is mixing altitudes. Orchestrators call named steps; leaf methods do one computation.
- **Can you describe it in one sentence with no clauses?** If the sentence needs a semicolon,
  the method needs a split.

### What this looks like here

Good — every one of these is fully described by its name, and
[report_presenter.rb](app/presenters/report_presenter.rb) is the best example in the repo:

```ruby
# app/presenters/report_presenter.rb:172
def ranked_top?(position, threshold)
  position.present? && position <= threshold
end

# app/presenters/report_presenter.rb:176
def percent_change(current, previous)
  return nil if current.nil? || previous.nil? || previous.zero?

  ((current - previous).to_f / previous * 100).round
end
```

Those two private leaves let `keywords_top10_count`, `keywords_top3_count`,
`citation_impressions_change_pct`, and `citation_engagements_change_pct` each stay a single
readable line. That's the pattern to copy.

Not yet there — [`ReportGenerator#sync_gbp_activity`](app/services/report_generator.rb) at
`report_generator.rb:143` is named for one thing and does four: it writes the GBP summary,
replaces posts, replaces reviews (deriving sentiment inline), and replaces photos. By the test
above it should be:

```ruby
def sync_gbp_activity(report, gbp)
  return if gbp.blank?

  sync_gbp_summary(report, gbp)
  sync_gbp_posts(report, gbp[:posts])
  sync_gbp_reviews(report, gbp[:reviews])
  sync_gbp_photos(report, gbp[:photos])
end
```

`sync_traffic` (`report_generator.rb:65`) has the same shape — GA4 branch, GHL branch, and
status derivation in one body. **When you touch either method, split it rather than adding to
it.** Don't refactor them speculatively in an unrelated change.

### Hard limits

| Thing | Limit | On exceeding |
|---|---|---|
| Method body | ~10 lines | Extract a named private method |
| Nesting depth | 2 levels | Guard clause, or extract |
| Method params | 3 positional | Switch to keyword args |
| Boolean params | 0 | Two methods, or an explicit keyword |
| Class | ~200 lines | Split by responsibility |
| ERB partial | ~80 lines | Extract a sub-partial |

Limits are guidance, not lint. Exceeding one is a prompt to look for the split, not an error.

---

## Readability rules

- **Guard clauses, never nested conditionals.** Handle the exceptional case and return.
  `keyword_movement` (`report_presenter.rb:143`) is a five-guard ladder with zero nesting —
  copy that shape.
- **No nested ternaries.** `report_generator.rb:165` currently has
  `rating <= 2 ? "negative" : (rating == 3 ? "neutral" : "positive")`. Derivations like this
  belong on the model as a named method (`GbpReview#sentiment_from_rating`), not inline in an
  orchestrator.
- **Name intermediate values.** A local with a good name beats a comment and beats a long chain.
- **Predicates end in `?` and return a real boolean.** `ga4_available?`, `ghl_connected?`,
  `first_report?`.
- **Bang methods raise; plain methods don't.** Follow Rails: `save!`/`update!` inside services
  where a failure is a bug; `save` in controllers where you render `:edit` on failure.
- **`unless` only for a single positive condition, never with `else`,** never with `&&`/`||`.
- **Positive booleans.** `configured?` not `not_configured?`.
- **Symmetry.** Parallel operations get parallel names and parallel shapes — `sync_hubspot`,
  `sync_traffic`, `sync_yext`, `sync_keywords`, `sync_highlights` all read at the same altitude
  in `ReportGenerator#call`, which is why that method is scannable.
- **`frozen_string_literal: true`** on new plain-Ruby files (models and concerns here use it).

---

## Simplicity

- **Delete before you abstract.** Duplication that isn't causing bugs is cheaper than the wrong
  abstraction.
- **Rule of three.** Extract on the third occurrence, not the second.
- **No speculative generality.** No config option, no strategy class, no `options = {}` hash for
  a case that doesn't exist yet. YAGNI is enforced here.
- **Prefer the framework.** If you're writing what Rails or Active Support already does
  (`Array()`, `presence`, `slice`, `compact`, `find_or_initialize_by`, `beginning_of_month`),
  delete yours.
- **One reason to change per class.** `HighlightGenerator` builds summary copy;
  `ReportGenerator` orchestrates. Neither knows the other's internals.
- **Don't add a layer to hold one method.** A presenter, service, or concern earns its file by
  having a real responsibility, not by existing for symmetry.

---

## Controllers: actions only, no private methods

**A controller file contains public RESTful actions and nothing else.** No `private` section.
No `set_*` loaders, no `*_params` methods, no guard methods, no `rescue_from` handler methods.
If a controller needs behaviour beyond its actions, that behaviour lives in
`app/controllers/concerns/` and is mixed in.

Permitted in a controller file:

- `layout`, `before_action`, `skip_before_action`, `rescue_from`, `include` declarations
- the seven actions: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`

That's it. **An action does at most four things: authorize, load, delegate, respond** — budget
**≈5 lines**, and no conditional beyond the `if @record.save` / `else` branch.

### Where the private methods go instead

| What you'd have written | Where it goes |
|---|---|
| `set_thing` / `find_thing` loader | a concern, `included do before_action :set_thing end` |
| `thing_params` strong params | the same concern that loads the resource |
| `require_*!` guard | a concern (`Authentication`, `Authorization`) |
| `rescue_from ..., with: :handler` | `rescue_from ... do ... end` — block form needs no method |
| `helper_method`-exposed reader | the concern that defines it |
| Data shaping for the view | a model scope/class method, or a presenter |
| Multi-model write or an API call | `app/services/` |
| Anything slow, retryable, scheduled | `app/jobs/` (IDs in, not objects) |

A concern is the right home because it names the behaviour (`FindsConnection`,
`Authentication`) and makes it testable and reusable, which a private method buried in one
controller never is. This is also what Rails 8 itself generates — its auth scaffolding ships as
`app/controllers/concerns/authentication.rb`, not as private methods on `ApplicationController`.

### The three controllers do not comply yet

All three currently keep private methods, so treat these as the migration targets — refactor the
controller you're already touching, not all of them at once.

**[ConnectionsController](app/controllers/connections_controller.rb)** — three private methods
(`set_connection`, `ensure_configurable!`, plus inline permitting in `update`) and a
blank-means-unchanged credential merge the controller shouldn't know about. Target:

```ruby
class ConnectionsController < ApplicationController
  include FindsConnection

  def index
    @connections = AgencyConnection.all_services
  end

  def edit
  end

  def update
    if @connection.update_credentials(connection_params)
      redirect_to connections_path, notice: "#{@connection.display_name} credentials updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
```

`FindsConnection` owns `set_connection`, `ensure_configurable!`, and `connection_params`;
`AgencyConnection#update_credentials` owns the merge semantics (it already owns
`CREDENTIAL_FIELDS`); `AgencyConnection.all_services` replaces the `services.keys.map` shaping
currently inline in `index`.

**[ReportsController](app/controllers/reports_controller.rb)** — its `report_not_found` handler
becomes a block, and the 11-line `includes` list becomes a `MonthlyReport` scope, leaving one
line:

```ruby
class ReportsController < ApplicationController
  layout "report"
  skip_before_action :authenticate_admin!

  rescue_from ActiveRecord::RecordNotFound do
    render "reports/not_found", status: :not_found
  end

  def show
    @report = ReportPresenter.new(MonthlyReport.for_public_view.find_by!(access_token: params[:access_token]))
  end
end
```

**[ApplicationController](app/controllers/application_controller.rb)** — `current_admin_user`,
`authenticate_admin!`, and `require_editor!` move to
`app/controllers/concerns/authentication.rb`, which `ApplicationController` includes. The rule
applies to the base class too; being shared is what makes it a concern, not what exempts it.

Also non-negotiable, per CONVENTIONS.md §9: strong parameters on every input action, correct
status codes (`render :edit, status: :unprocessable_entity`), the 7 RESTful actions, no DB
queries in views, never render *and* redirect.

---

## Long methods and information processing

Whenever a method grows past ~10 lines, or does any real information processing, **work down this
ladder and stop at the first step that fits.** Most fixes stop at step 1. Do not skip to step 3
— a new file is the most expensive answer, not the default one.

### Step 1 — Compose method (the default, ~90% of cases)

Turn the long method into an orchestrator that calls named private methods **in the same class**.
No new file, no new concept. The method body becomes a table of contents you can read top to
bottom.

`ReportGenerator#call` (`report_generator.rb:20`) already has this shape — a guard, then five
named `sync_*` steps, then the result. `sync_gbp_activity` (`report_generator.rb:143`) is the
same problem one level down and gets the same fix: four named private steps.

**Controllers are the one exception:** they get no private methods at all, so a long action skips
straight to a concern (step 3) or to the model/service that should own the work. See
[Controllers](#controllers-actions-only-no-private-methods).

### Step 2 — Move it to the object that owns the data

If the extracted code mostly reads *another* object's attributes, it belongs on that object, not
here (feature envy). Ask: "whose data is this?"

The sentiment derivation at `report_generator.rb:165` reads only `review[:rating]`, so it belongs
on `GbpReview`, not in the generator. Same test for any `if record.foo && record.bar` chain in a
service — that's a predicate the model should expose.

### Step 3 — Extract a new object

Only when the extracted methods form a **cluster with its own identity** that doesn't use the
host class's state. Signals: three or more methods that only talk to each other, a name that
isn't a verb about the host, or the host class passing the same 2–3 arguments around.

Then pick by what the cluster *does*:

| The processing is | Extract to | Interface |
|---|---|---|
| A read — filtering, joining, assembling a result set | `app/queries/*_query.rb` | `#call` returns a relation |
| A write or a multi-step operation | `app/services/*.rb` | `#call` |
| Pure computation — no DB, no network, no `Time.current` | a value object (`Data.define`) or `*Calculator` | a named method |
| Shaping one record for a view | `app/presenters/*_presenter.rb` | named readers |
| Talking to one external API | `app/services/adapters/*_adapter.rb` | `#call` → `Result` |

**Real step-3 candidate in this repo:** `ReportPresenter` carries six coupled keyword methods —
`keyword_movement`, `keyword_change`, and the four `keyword_*_count` folds
(`report_presenter.rb:143-168`). They only talk to each other and to a row, never to the report.
That cluster is a `KeywordMovement` value object (or `KeywordSummary` calculator) waiting to
happen. It is *fine as-is today* — extract it when it next grows, not speculatively.

### Vocabulary: one word per concept

**Do not introduce `app/actions/`, `app/operations/`, `app/interactors/`, `app/commands/`, or
`app/use_cases/`.** This project has one word for "a business operation": a **service** in
`app/services/` exposing `#call` (CONVENTIONS.md §16). Adding a parallel vocabulary is the single
fastest way to make code unfindable — a reader then has to guess which of five directories holds
the thing they want.

`app/queries/` and value objects are additions to that vocabulary, not competitors: a query is a
read, a service is a write, a value object is a calculation. Create either directory the first
time you genuinely need it, never in advance.

---

## Which layer owns it

Pick the innermost layer that can own it.

| Layer | Owns | Example |
|---|---|---|
| **Controller** (`app/controllers/`) | HTTP only — actions, no private methods | [ReportsController](app/controllers/reports_controller.rb) |
| **Controller concern** (`app/controllers/concerns/`) | Loading, guarding, strong params, auth | `Authentication`, `FindsConnection` |
| **Model** (`app/models/`) | Persistence, validation, enums, scopes, derivations from own columns | `AgencyConnection#status_label`, `Client` scopes |
| **Model concern** (`app/models/concerns/`) | A behaviour shared by 2+ models | [HasUuidPrimaryKey](app/models/concerns/has_uuid_primary_key.rb) |
| **Query** (`app/queries/`) | A read too complex for a scope | *none yet — create on first need* |
| **Presenter** (`app/presenters/`) | View-only computation and DB access kept out of ERB | [ReportPresenter](app/presenters/report_presenter.rb) |
| **Service** (`app/services/`) | A business operation spanning models or hitting the network | [ReportGenerator](app/services/report_generator.rb), `HighlightGenerator` |
| **Adapter** (`app/services/adapters/`) | One external API; returns `Result`, never raises past `#call` | [Adapters::Base](app/services/adapters/base.rb) + one file per service |
| **Job** (`app/jobs/`) | Scheduling/retry only — a thin wrapper over a service | [GenerateMonthlyReportJob](app/jobs/generate_monthly_report_job.rb) |
| **Helper** (`app/helpers/`) | Markup-producing view utilities | `report_icon`, `icon_badge` |
| **View** (`app/views/`) | Markup. No queries, no arithmetic, no business conditionals |  |

### Services

Instantiate with dependencies as **keyword arguments**, expose **`#call`**, keep every step
private:

```ruby
ReportGenerator.new(client: client, month: Date.new(year, month, 1)).call
```

`#call` should read as a table of contents (`report_generator.rb:20-40`) — a guard, then named
steps, then the result.

### Adapters

Every adapter subclasses `Adapters::Base`, sets `SERVICE`, and implements `#perform`. `Base`
owns credential resolution (client override → agency fallback), Faraday setup with retries, and
the `Faraday::Error` rescue. `#perform` raises `NotImplementedError` — that's the contract.

Adapters **return, never raise**:

```ruby
# app/services/adapters/result.rb:5
Result = Data.define(:success?, :data, :error)
```

This is deliberate: one dead API degrades one report section into a placeholder rather than
failing the whole run. Preserve that property. `ReportGenerator` collects `warnings` per adapter
and only marks an attempt `"failed"` on an unexpected exception — a real bug — which it logs and
then **re-raises** (`report_generator.rb:37-40`). Never swallow.

---

## Scalability and efficiency

- **The public report is the hot path.** It renders ~8 sections over a dozen associations, all
  preloaded by one `includes`. **When you add a report section, add its association to that
  preload list** — otherwise you ship an N+1 on the one page clients actually load. The list
  belongs in a `MonthlyReport.for_public_view` scope (it is inline in
  `ReportsController#show` until that controller is refactored — either way, it is the one place
  to update).
- **`.sort_by` on an already-loaded association; `.order` only on an unloaded relation.** This
  is why `ReportPresenter#keyword_rows` and `#gbp_posts` use `sort_by` — the rows are already in
  memory from `includes`, and `.order` would fire a fresh query and defeat the preload. Getting
  this backwards silently undoes the N+1 fix above.
- **Aggregate with `count {}` over loaded rows, not `COUNT(*)` per call.** `keywords_top10_count`,
  `keyword_gained_count`, etc. all fold over the memoized `keyword_rows`. Per CONVENTIONS.md §26
  these aggregates are computed at runtime and never stored.
- **Two memoization idioms, and they are not interchangeable:**

  ```ruby
  @agency_connection ||= AgencyConnection.find_by(...)          # value can't be nil
  return @previous_report if defined?(@previous_report)          # nil is a valid, cacheable answer
  @previous_report = client.monthly_reports.find_by(...)
  ```

  Use `defined?` whenever `nil` is a legitimate result (`Base#client_service_link`,
  `ReportGenerator#previous_report`) — `||=` re-queries on every call for those.
- **Index every column you filter or join on**, and back real invariants with DB constraints, not
  just validations (`monthly_reports` has a unique `(client_id, report_month)`).
- **Keep writes idempotent.** `ReportGenerator` is safe to re-run for a client/month:
  `find_or_create_by!` for the report, replace-then-create for child rows. Retries after a
  partial failure must never duplicate data.
- **Jobs take IDs, not records** — serializable payloads survive a deploy mid-queue.
- **`decimal` for money and percentages, never `float`.**
- Batch with `find_each` / `in_batches` over unbounded sets; never `.all.each`.

---

## Comments: explain *why*, never *what*

This codebase is unusually good at this — match it. Every non-obvious decision carries its
reason, often with a link to the constraint that forced it:

- `report_presenter.rb:88` — why `ai_visibility` is frozen per report instead of re-derived from
  `client.ai_seo_enrolled?` (so a later enrollment change can't rewrite history).
- `has_uuid_primary_key.rb` — why the concern survives the MySQL→Postgres migration even though
  `pg` no longer needs it.
- `agency_connection.rb` — why `badge_class` holds a complete Tailwind class string instead of
  being assembled from a colour name.
- `generate_monthly_report_job.rb` — why the job isn't in `recurring.yml` yet.

Rules: no comment restating the code; no commented-out code; a `TODO` needs an owner or a
reason; when you change behaviour, **update the comment that explains it** — a stale *why* is
worse than none.

---

## Views and styling

- **No business logic in ERB.** No queries, no arithmetic, no multi-branch conditionals. If a
  view needs a computed value, it goes on the presenter or a helper.
- **Declare strict locals in every partial.** The house style is the magic comment already used
  throughout `app/views/reports/`:
  ```erb
  <%# locals: report (ReportPresenter) %>
  ```
- **Never inline SVG in a view.** Icons go through `report_icon` / `icon_badge` in
  [reports_helper.rb](app/helpers/reports_helper.rb). A new icon means a new entry in
  `ICON_INNER` (Lucide-matched), not markup in a template.
- **Use the design tokens, not raw hex.** Defined in
  [app/assets/tailwind/application.css](app/assets/tailwind/application.css):

  | Token | Value | Use |
  |---|---|---|
  | `--color-teal-primary` | `#0d9488` | Primary brand, CTAs, active nav, progress fills |
  | `--color-teal-dark` | `#0f766e` | Brand text on light, hover, icon glyphs |
  | `--color-cyan-primary` | `#06b6d4` | Gradient partner to teal (report header) |
  | `--color-cyan-light` | `#22d3ee` | Gradient/accent extension |

  Supporting palette, applied consistently: **slate** for all neutrals (`slate-50` page wash,
  `slate-900` headings, `slate-600`/`slate-500` body and muted, `slate-200` borders);
  **emerald** for positive movement and the one "hero" stat; **amber**/**red** for warning and
  negative; **violet** for AI-SEO surfaces; **cyan** for informational.
- **Shape vocabulary:** `rounded-2xl` cards, `rounded-xl` inner tiles, `rounded-lg` controls,
  `border border-slate-200`, `shadow-sm`, `p-5`/`p-6` card padding.
- **Tailwind can't see interpolated class names.** Only literal class strings present in source
  get compiled. Never build `bg-#{color}-500`; map to complete class strings, as
  `AgencyConnection::DISPLAY` does.
- **Extract a partial when markup repeats**, not a CSS component class — this app is
  utility-first with no component CSS layer, and `_stat_card` / `_section_card` are the
  established pattern for reuse.
- **Mobile matters more than desktop** for the public report, and the admin panel must not
  break on a phone either — MSP staff do check it from one. Verify both at 390px, 768px,
  1280px; check nothing overflows horizontally. Patterns for the recurring cases (off-canvas
  nav, wide tables, stat grids) are in
  [design-system.md#responsiveness](docs/reference/design-system.md#responsiveness) — reuse
  them rather than inventing a new approach per page.
- **Behaviour rules live in [Frontend behaviour](#frontend-behaviour)** — Stimulus, Turbo, and the
  no-JavaScript-only-paths rule.

---

## Testing

CONVENTIONS.md §18 covers Minitest mechanics. This section is what's specific to this system:
what to test per layer, how to fake the five external APIs, and the two decisions where we
knowingly diverge from §18.

### Test data: builders, not fixtures

**This project does not use fixtures.** `test_helper.rb` declares `fixtures :all` and
`test/fixtures/` is empty, and that is intentional — it stays declared so fixtures work the day
one is added, but building records explicitly is the convention here. Two hard technical reasons:

1. **UUID string primary keys.** Tables use `t.string :id, limit: 36`. Rails generates fixture
   IDs by hashing the label into an *integer*, so every fixture and every cross-reference would
   need an explicit `id: <%= SecureRandom.uuid %>` and manual wiring — all the fragility of
   fixtures with none of the convenience.
2. **Active-Record-encrypted columns.** `AgencyConnection#encrypted_credentials` and
   `ClientServiceLink#override_credentials` are `encrypts`ed. Fixtures INSERT raw rows and bypass
   encryption, so a fixture value would be stored as plaintext and blow up on read.

So: **build what the test is about, in `setup` or a named builder.** This contradicts
CONVENTIONS.md §18's "use fixtures for speed" — that section should be amended; the reasons above
win.

Keep builders honest:

- Suffix unique columns so parallel workers can't collide —
  `"Test Practice #{SecureRandom.hex(4)}"`, as `reports_controller_test.rb` does.
- One named builder per test file beats inline setup repeated five times
  (`build_monthly_report` in `reports_controller_test.rb` is the model).
- **Shared builders belong in `test/support/`, not as private methods in one test file.**
  `sign_in_as` (`connections_controller_test.rb:84`) is trapped where only one file can use it,
  and `sessions_controller_test` needs the same thing. Extract to a module, and require it from
  `test_helper.rb` — `test/support/` is not autoloaded:

  ```ruby
  # test/test_helper.rb
  Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

  class ActionDispatch::IntegrationTest
    include AuthenticationHelpers
  end
  ```

### External APIs: WebMock, always

`WebMock.disable_net_connect!` is global — **a test that reaches the network fails, by design.**
Every adapter call must be stubbed.

[report_generator_test.rb](test/services/report_generator_test.rb) is the reference for this and
for coverage generally. Copy its shape:

- One `stub_request` per external endpoint in `setup`, with the **real** response shape
  (SEMrush returns semicolon CSV, not JSON — stub it as CSV).
- Override a single stub inside a test to change one service's behaviour, rather than rebuilding
  setup.
- Pass an array of responses to `to_return` to script successive calls — that's how the
  previous-month carry-forward test drives two months from one stub.
- **Assert the negative too.** `assert_not_requested :get, ".../calendars/events"` is what proves
  "we don't call GHL when no link exists" — a positive assertion alone can't.

### What to cover, per layer

| Layer | Test as | Must cover |
|---|---|---|
| **Adapter** | Unit + WebMock | Success parse, non-200, timeout → `Result.failure`, missing credentials |
| **Service** | Unit + WebMock | Happy path, **idempotency**, each degraded state, each business rule, each guard, error logged + re-raised |
| **Presenter** | Plain unit, no HTTP | Every computed number, and every `nil` input path |
| **Model** | Unit | Validations, enums, scopes, derivations, token generation |
| **Controller** | `ActionDispatch::IntegrationTest` | Auth/role gates, each response shape, 404s, that secrets never appear in the body |
| **Job** | Unit | Enqueues, retries/discards, delegates to its service |
| **System** | Capybara | Only genuinely interactive flows (login, the month switcher) |

The five-case pattern for any service, all present in `report_generator_test.rb`: happy path ·
idempotent re-run · degraded dependency · business rule respected · guard raises · failure logged
then re-raised.

For controllers, assert on **user-visible content**, not markup structure —
`assert_select "span", text: "First report — baseline month"` survives a restyle;
`assert_select "div.rounded-2xl > p:first-child"` doesn't.

**Security assertions are not optional** where secrets are involved. `connections_controller_test`
asserts `assert_no_match(/super-secret-token/, response.body)` on both `edit` and `update` —
every new credential surface needs the equivalent.

### Lock the N+1 fix with a query count

The report preload rule is only enforceable if a test fails when someone breaks it.
`assert_queries_count` is available in every test with no setup (`rails/test_help` includes
`ActiveRecord::Assertions::QueryAssertions`), so pin the report render:

```ruby
test "renders the report without N+1 queries" do
  report = build_monthly_report(...)

  assert_queries_count(EXPECTED) do
    get public_report_path(report.access_token)
  end
end
```

Establish `EXPECTED` by running it once, then treat any increase as a regression to explain rather
than a number to bump. `assert_no_queries` is the right tool for presenter methods that must fold
over already-loaded rows.

### Time

The report domain is month-based, so be deliberate:

- Services guarded against "the current month" (`ReportGenerator`) must use **relative** dates —
  `Date.current.beginning_of_month - 1.month` — or the test rots next month.
- Rendered-output tests may use **fixed** dates (`Date.new(2026, 6, 1)`) when the asserted string
  contains the date.
- Use `travel_to` for anything asserting behaviour *at* a month boundary. Never `sleep`.

### Current coverage gaps

`test/services/` and `test/controllers/` are real. `test/models/`, `test/presenters/`,
`test/helpers/`, `test/integration/`, and `test/system/` are `.keep` only. Ranked by value:

1. **`ReportPresenter` has zero tests** and is the biggest gap in the suite. It owns
   `keyword_movement`, `percent_change`, `visit_share_pct`, and six aggregate folds — pure
   functions, trivial to test, and they compute every number a client sees. Start here.
2. `AgencyConnection#status_label` / `#status_dot_class` — pure branching, no coverage.
3. `MonthlyReport` — `access_token` generation, the `(client_id, report_month)` uniqueness.
4. System tests for login and the month switcher (**see the WebMock blocker below first**).

---

## CI

Two runners, and they must agree:

- **`bin/ci`** ([config/ci.rb](config/ci.rb)) — the local gate. Sequential; sets `CI=true`, which
  turns on `config.eager_load` in the test env, so Zeitwerk naming errors surface locally the
  same way they do on GitHub.
- **[.github/workflows/ci.yml](.github/workflows/ci.yml)** — the PR gate. Five parallel jobs
  (`scan_ruby`, `scan_js`, `lint`, `test`, `system-test`) against a `postgres` service container.

**`bin/rails docs:check` runs in both**, as a step of the `lint` job on GitHub. It verifies every
source file is named in a document, every link resolves, and every Key files table entry points
at a path that exists — the last of which is what keeps the "grep `docs/` for the file you
changed" rule true. It needs no database, which is why it sits in `lint` rather than `test`.
**A rename that leaves a document behind now fails the build**, which is the whole point:
documentation rots silently otherwise.

**Run `bin/ci` before pushing.** Job-level parallelism is a legitimate difference between the two;
differences in *what passes* are bugs. There are three right now:

1. **Brakeman is stricter locally than on GitHub.** `bin/ci` runs
   `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`; the workflow runs
   `bin/brakeman --no-pager`. A Brakeman *warning* therefore fails your machine and passes the PR.
   Add `--exit-on-warn --exit-on-error` to the workflow.
2. **System tests run on GitHub but not locally** — `config/ci.rb:15` has the step commented out,
   so `bin/ci` green does not imply CI green once `test/system/` has content. Uncomment it.
3. **`db:seed:replant` runs locally but not on GitHub**, so a broken `db/seeds.rb` merges cleanly.
   Add it to the workflow's `test` job.

### CI facts worth not re-deriving

- **`RAILS_MASTER_KEY` is deliberately unset in CI** (commented out in the workflow) and that is
  correct — [active_record_encryption.rb](config/initializers/active_record_encryption.rb) falls
  back to fixed insecure keys outside production, so encrypted-column tests pass without secrets.
  Don't "fix" this by adding the secret.
- The workflow's RuboCop cache key hashes `.ruby-version` (present, `3.3.7`), `**/.rubocop.yml`,
  and `Gemfile.lock` — bumping any of them is a cache miss, not an error.
- Failed system-test screenshots upload as a `screenshots` artifact; check it before re-running a
  red system job.

### Blocker: WebMock breaks system tests

`test_helper.rb:7` is `WebMock.disable_net_connect!` with no `allow_localhost` option, and
WebMock's default is to block localhost. Capybara and Selenium talk to chromedriver and the Puma
test server over localhost, so **the first system test written will fail with
`WebMock::NetConnectNotAllowedError`** — not with a real failure.

The `system-test` job passes today only because `test/system/` is empty. Fix it before writing any
system test:

```ruby
# test/test_helper.rb
WebMock.disable_net_connect!(allow_localhost: true)
```

This still blocks every external API — localhost is the test server, not a third party.

---

## Security

CONVENTIONS.md §19 has the general rules. What matters here is that **this app has exactly two
trust boundaries**, and both are unusual:

1. **The public report URL is the credential.** `/reports/:access_token` has no session, no login,
   no ownership check — possession of a 256-bit token *is* authorization. That makes the token a
   secret with all the handling rules of a password.
2. **Admin credentials for five third-party APIs live in our database**, encrypted at rest, and one
   leak exposes every client's data in those services.

### Rules

- **Never render a stored credential back to the user.** The Connections form deliberately shows
  blank fields even when a value exists, and `connections_controller_test` asserts the secret does
  not appear in the response body. Any new credential surface needs the same test.
- **`encrypts` for anything secret at rest** — `AgencyConnection#encrypted_credentials`,
  `ClientServiceLink#override_credentials`. Never add a plaintext secret column.
- **Every mutating admin action goes through a role gate.** `require_editor!` restricts writes to
  `admin`; `support` is read-only. New destructive actions must opt in, and the test must prove
  `support` is blocked (not just that `admin` is allowed).
- **Strong params everywhere**, no `params[:x]` straight into a model.
- **No secret in a URL, ever** — the report token is the one exception, and it's why the report
  layout is `noindex,nofollow`.
- **Brakeman must be clean.** It runs in `bin/ci` with `--exit-on-warn`; treat a warning as a
  failure, and if it's a genuine false positive, annotate it rather than loosening the flag.

### Open gaps, in priority order

These are real and currently unaddressed. Fix them when you're next in the relevant file.

1. **Login has no rate limiting** — [SessionsController#create](app/controllers/sessions_controller.rb)
   accepts unlimited attempts, so credential stuffing is free. Rails 8 ships this:

   ```ruby
   rate_limit to: 10, within: 3.minutes, only: :create
   ```

   It needs a real cache store; production has `:solid_cache_store`, but the test env is
   `:null_store`, so a test asserting the limit must swap the store in.

2. **Login leaks which emails exist.** `AdminUser.find_by(email:)&.authenticate(password)` skips
   bcrypt entirely for an unknown address, so the response is measurably faster — a timing oracle
   for valid accounts. Rails has a constant-work replacement:

   ```ruby
   admin_user = AdminUser.authenticate_by(email: session_params[:email]&.strip&.downcase,
                                          password: session_params[:password])
   ```

3. **No session reset on login** — session fixation. `reset_session` before assigning
   `session[:admin_user_id]`.

4. **`force_ssl` and `assume_ssl` are commented out** in
   [production.rb:28-31](config/environments/production.rb:28). Without them the session cookie
   isn't marked `secure` and there's no HSTS. Both must be on behind the production proxy.

5. **Report access tokens leak into production logs.** `filter_parameters` covers `:token`, but the
   access token is a **path segment**, not a param — so `Started GET "/reports/<token>"` is written
   verbatim to the log, and anyone with log access can open any client's report. Either scrub the
   path in a log subscriber or treat production logs as containing client-report credentials and
   restrict access accordingly. Decide explicitly; don't leave it undecided.

6. **`config.hosts` is unset** (commented out at
   [production.rb:83](config/environments/production.rb:83)) — no DNS-rebinding protection. Set the
   real hostname, keeping `/up` excluded for the health check.

---

## Database and migrations

CONVENTIONS.md §3 covers the migration DSL. Project-specific discipline:

- **Follow the UUID table shape exactly** — see [Known gotchas](#known-gotchas). Getting it wrong
  produces a table that silently doesn't match the rest of the schema.
- **Back real invariants with DB constraints, not just validations.** `monthly_reports` has a unique
  `(client_id, report_month)` index *and* a model validation — the index is what actually prevents
  a duplicate under concurrency. Uniqueness validated only in Ruby is a race, not a constraint.
- **`null: false` on anything a query assumes is present**, and an index on every column you filter
  or join by.
- **`decimal` with explicit precision/scale for money and percentages.** Never `float` —
  `estimated_revenue` is `decimal`, keep it that way.
- **Multi-step changes, not one destructive migration.** Adding a required column to a populated
  table is three deploys: add nullable → backfill in a job or task → add the constraint. Renaming
  or dropping a column is likewise additive-then-remove. A migration that rewrites a big table
  locks it.
- **Never edit a migration that has run.** Never put `update_all`/`create` in a schema migration —
  data changes belong in `db/seeds.rb` or a one-off task.
- **Four databases in production** — primary, queue, cache, cable
  ([production.rb:54](config/environments/production.rb:54)). App migrations target primary only;
  Solid Queue/Cache/Cable own their own schemas.
- **`Client` is `discard`ed and there is no default scope.** `Client.all` includes discarded rows —
  use `Client.kept` anywhere a soft-deleted practice must not appear, including in report
  generation and any future client list.

---

## Background jobs and scheduling

- **A job is a wrapper, never a home for logic.** `perform` resolves IDs to records and calls one
  service. [GenerateMonthlyReportJob](app/jobs/generate_monthly_report_job.rb) is the template.
- **IDs in, not objects** — a serialized record can go stale or fail to deserialize across a deploy.
- **Every job must be idempotent**, because every job can be retried. `ReportGenerator` is safe to
  re-run for the same client and month; anything you enqueue must have that property or a guard.
- **Declare the failure policy explicitly.** `retry_on` for transient faults (`Faraday::TimeoutError`,
  `Faraday::ConnectionFailed`) with `wait: :polynomially_longer`; `discard_on` for permanent ones
  (`ActiveRecord::RecordNotFound`). A job with neither retries forever on a bug.
- **Scheduled work goes in [config/recurring.yml](config/recurring.yml)** under the `production`
  key. It currently holds only Solid Queue's own cleanup — **monthly report generation is not
  scheduled**, matching the note in the job. Whoever wires it must also decide the send date
  (SOW #6 leaves it open) and must schedule for a *completed* month.
- **Confirm the worker actually runs.** [puma.rb:38](config/puma.rb:38) starts Solid Queue in-process
  **only if `SOLID_QUEUE_IN_PUMA` is set**, and the Dockerfile's `CMD` runs just the web server. If
  that variable isn't set in the deploy environment, enqueued jobs sit in the queue forever with no
  error. Verify it, or run `bin/jobs` as a separate process.

---

## Observability and operations

**There is no error-tracking service** (no Sentry, no Honeybadger). Two consequences shape how you
write code here:

1. **The domain tables *are* the audit trail.** `ReportGenerationLog` (status, `attempted_at`,
   `error_summary`, `error_log`) and `SendLog` are how anyone learns what happened. Preserve that:
   `ReportGenerator#log_attempt` records a row on both success and failure, and stores per-adapter
   warnings even on success — so a report that generated with three sections missing is
   *discoverable*. Any new long-running operation needs the same treatment.
2. **Failures are currently invisible.** Nothing surfaces `ReportGenerationLog` where a human sees
   it — no admin screen, no alert. A month's generation can half-fail silently. The Dashboard page
   (stubbed today) is the natural home for a "recent failures" view; treat that as a real
   operational requirement, not a nice-to-have.

Logging rules:

- `config.log_level` is `ENV["RAILS_LOG_LEVEL"]`, default `info`.
- **Log context, never secrets.** No credentials, no report tokens, no full API responses. Add new
  sensitive param names to
  [filter_parameter_logging.rb](config/initializers/filter_parameter_logging.rb).
- **Raise or return — never rescue into silence.** `rescue nil` and bare `rescue StandardError` that
  swallows are banned. The one broad rescue in the codebase (`ReportGenerator#call`) logs and then
  **re-raises**; that's the only acceptable shape.
- Distinguish the two failure kinds the app already distinguishes: an **external API being down** is
  a warning and a degraded section; an **unexpected exception** is a bug, logged as `failed` and
  re-raised.

---

## Deployment and environments

- **Container-based:** [Dockerfile](Dockerfile) → `bin/thrust bin/rails server`, `EXPOSE 80`.
  Thruster handles compression, caching, and X-Sendfile.
- **The real target appears to be Railway**, per
  [active_record_encryption.rb](config/initializers/active_record_encryption.rb) referencing its
  Variables tab. **[config/deploy.yml](config/deploy.yml) is untouched Kamal boilerplate** —
  `192.168.0.1`, registry `localhost:5555`, SSL commented out. Don't read it as the deployment
  truth, and don't half-configure it: either make Kamal real or delete it so there's one answer.
- **Required environment variables:**

  | Variable | Purpose |
  |---|---|
  | `DATABASE_URL`, `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL`, `CABLE_DATABASE_URL` | the four databases |
  | `RAILS_MASTER_KEY` | credentials, if used in place of the AR-encryption env vars |
  | `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT` | encrypted columns; generate with `bin/rails db:encryption:init` |
  | `SOLID_QUEUE_IN_PUMA` | runs the worker in-process (see Jobs) |
  | `RAILS_LOG_LEVEL` | optional, defaults to `info` |

- **Production raises without real encryption keys** — deliberately. The dev/test fallbacks are
  insecure by design and the initializer's only exemption is `SECRET_KEY_BASE_DUMMY=1` during
  `assets:precompile` in the Docker build. Don't widen that exemption.
- **`config.action_mailer.default_url_options` is `{ host: "example.com" }`**
  ([production.rb:61](config/environments/production.rb:61)). Every report link in an email would
  point at example.com. Fix this before the send feature ships — there is an
  `app/mailers/application_mailer.rb` and a `SendLog` model, but no mailer yet, so nothing sends
  today.
- **Assets:** Tailwind compiles at deploy into the gitignored `app/assets/builds/`. A token change
  needs no artifact committed, but it does need a successful build step.

---

## Accessibility

The public report is a deliverable sent to clients and read mostly on phones, so treat a11y as part
of the product, not polish.

- **Visual headings must be real headings.** The report nests correctly at the top level (`h1` in
  `_header`, `h2` per section via `_section_card`) but subsection titles like "Visits by Source" are
  styled `<p>` elements, so a screen reader gets a flat document with no way to skip between
  subsections. Use `<h3>` for those and style the class, not the tag.
- **Wrap each report section in `<section>` with an accessible name** tied to its `h2`, so the
  eight sections are navigable landmarks.
- **`alt` must degrade well.** [_gbp_activity.html.erb:98](app/views/reports/_gbp_activity.html.erb:98)
  renders `alt="<%= photo.caption %>"`, and caption is optional — a missing caption yields
  `alt=""`, which declares a meaningful photo decorative. Fall back to something descriptive.
- **Never convey meaning by colour alone.** Keyword movement, review sentiment, and credential
  status all use colour; each needs a text or icon cue too (`status_label` already does this
  correctly — match it).
- **Contrast:** verify against the slate ramp. `text-slate-500` on white passes for body copy;
  `text-slate-400` and `text-slate-300` do not — keep those for borders and disabled states, never
  for text a client must read.
- **Keep native controls.** The month switcher is a real `<select>` with a Stimulus action, so it is
  keyboard and screen-reader accessible for free. Don't replace it with a div-based dropdown.
- **Icons are decorative** — `report_icon` output needs `aria-hidden="true"` when it sits next to a
  text label, which is the common case.

---

## Frontend behaviour

- **Stimulus, not inline JS or `onclick`.** One controller per behaviour, named for the behaviour
  (`month_switcher`, `password_visibility`). Controllers are eagerly registered from
  `app/javascript/controllers/`, so a new file is picked up with no wiring.
- **Everything must work as plain HTML first.** The month switcher navigates on change; it is not a
  client-side render. No JavaScript-only paths in the report — a client's browser or email preview
  may not run it.
- **Turbo Drive is on by default.** Full-page forms should redirect on success and
  `render ..., status: :unprocessable_entity` on failure — Turbo requires the 422 to replace the
  form.
- **Reach for Turbo Frames/Streams only for genuinely partial updates,** and scope any future
  broadcast carefully — this app has no per-tenant channel, so a broadcast is global.
- **`bin/importmap pin` to add a package.** No Node build step; don't introduce one.
- **Delete dead controllers** — a Stimulus file no view references (e.g. `hello_controller.js`,
  removed as scaffolding cruft) is a liability, not neutral: it's still eagerly registered.

---

## Dependencies and i18n

- **Adding a gem needs a reason in the commit message** and a check that it's maintained. Every gem
  is attack surface that `bin/bundler-audit` then has to police, and `importmap audit` covers JS.
- **Prefer stdlib and Active Support** over a dependency for anything small.
- **Commit `Gemfile.lock`** with any `Gemfile` change; a lockfile change invalidates the CI cache
  key, which is expected, not an error.
- **No i18n today** — all copy is inline English in the ERB. Don't introduce `I18n` speculatively
  (that's the YAGNI rule), but *do* use `number_to_currency` / `number_with_delimiter` for numbers
  rather than hand-formatting, as the report already does.

---

## Domain invariants

CONVENTIONS.md §26 is the full list and it is binding. The ones easiest to break by accident:

- **Never generate or display a report for the current, incomplete month.** `ReportGenerator`
  raises `MonthNotCompleteError`; presenters must not surface an ungenerated month either.
- **Report tokens stay unguessable** — `SecureRandom.urlsafe_base64(32)`, no sequential IDs, no
  name slugs in public URLs.
- **Snapshotted report data is frozen.** Never retroactively recompute a past report from
  current client state.
- **`emailed_at` is the duplicate-send guard** — check it before sending.
- **AI summaries may only reference numbers present in that month's data**, max 2–3 sentences,
  and are **omitted entirely** rather than padded with filler.
- **Degrade, don't fail:** a missing integration renders a placeholder (`"?"` for GHL, section
  omitted for AI visibility) — never a broken page.

---

## Known gotchas

- **`enum` values that collide with Active Record methods need a prefix.**
  `AgencyConnection`'s `credential_status` uses `prefix: :credential` precisely because a bare
  `invalid` value would override `#invalid?` (validation state). Check for collisions when adding
  an enum.
- **UUID primary keys are declared by hand, not via `t.references`.** Copy the established
  migration shape ([create_monthly_reports.rb](db/migrate/20260728160004_create_monthly_reports.rb)):

  ```ruby
  create_table :monthly_reports, id: false do |t|
    t.string :id, limit: 36, primary_key: true, default: -> { "gen_random_uuid()" }
    t.string :client_id, limit: 36, null: false
    # ...
  end

  add_foreign_key :monthly_reports, :clients
  ```

  FK columns are plain `t.string ..., limit: 36` with a separate `add_foreign_key`. The model
  then includes `HasUuidPrimaryKey`.
- **`Report*` child tables key on `report_id`, not `monthly_report_id`** — so migrations need
  `add_foreign_key :report_traffics, :monthly_reports, column: :report_id` and the models need
  explicit `foreign_key: :report_id`. Follow the declarations in `MonthlyReport`.
- **`discard` does *not* add a default scope.** `Client.all` returns discarded records too.
  Query `Client.kept` wherever a soft-deleted client must not appear — this is the easy one to
  get wrong, since the gem's name suggests otherwise.
- **`app/assets/builds/` is gitignored** (only `.keep` is tracked), so Tailwind is compiled at
  deploy, not committed. A token change needs no build artifact in the commit — but it also
  means you must run `bin/dev` (which watches Tailwind) to see CSS changes locally.
- **Admin nav is partly stubbed.** Dashboard and Clients point at `connections_path` on purpose
  — don't "fix" the links; build the pages.
- **`db/seeds.rb`'s demo clients are guarded against production, and that guard is load-bearing,
  not decorative.** `bin/docker-entrypoint` runs `db:prepare` on every boot, and Rails' `db:prepare`
  runs `db:seed` automatically the first time it creates a fresh database — which is exactly how
  the 3 demo clients (Woodside/Bayview/Alameda, built to match the Lovable reference prototypes)
  ended up in a real production database that should have started empty. Any *new* seed data
  belongs above the `if Rails.env.production? ... return end` guard only if it's genuinely
  needed in every environment (like the `Service::KEYS` lookup-table seed); anything that looks
  like a fake client, keyword, or report belongs below it, never above.

---

## Definition of done

1. `bin/ci` passes (rubocop, bundler-audit, importmap audit, brakeman, tests, seeds).
2. Tests cover the change at the layer it lives in ([Testing](#testing)) — external calls stubbed
   with WebMock, negative assertions where "we don't call X" is the point, and a security
   assertion if a secret could leak into a response.
3. Every new method passes the naming test; no controller action exceeds its budget.
4. No N+1 introduced — new report associations added to the report preload list.
5. No private methods in any controller; no method over ~10 lines.
6. Views verified at 390px / 768px / 1280px if there's a render delta, with real headings and
   working `alt` text ([Accessibility](#accessibility)).
7. `db/schema.rb` committed with any migration; new invariants backed by a DB constraint, not only a
   validation.
8. Nothing secret added to a log, a URL, a plaintext column, or a rendered response
   ([Security](#security)).
9. Any new long-running operation records its outcome where a human can find it
   ([Observability](#observability-and-operations)).
10. Non-obvious decisions carry a *why* comment; stale comments updated.

See [Testing](#testing) for what to cover per layer and [CI](#ci) for the two runners — including
three ways `bin/ci` and the GitHub workflow currently disagree.

---

## Git

- **Never commit unless explicitly asked.** One commit per request unless more are requested.
- **Do not add a `Co-Authored-By: Claude` trailer** to commits in this repo.
- Feature branches (`feature/*`, `fix/*`, `docs/*`), atomic commits, descriptive messages.
- Never commit `config/master.key`, `config/credentials/*.key`, or `.env`.
- Never force-push `main`.
