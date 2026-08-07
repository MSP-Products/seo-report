# Brief — Team management for the MSP admin panel

**Deliverable:** an admin-panel page where an owner can invite MSP staff to the admin panel,
assign and change their role, and deactivate them — replacing the rake task and Rails console
that are the only ways to do this today.

**Repo:** this one. **Branch:** cut `feature/team-management` from `main`.
**Stack:** Rails 8.1, PostgreSQL, Hotwire, Tailwind v4, Minitest. No Node build step.

---

## The product in one paragraph

**My Social Practice — SEO Reports.** Once a month, for each dental practice MSP works with,
the system pulls data from five external services (HubSpot, GoHighLevel, Yext, SEMrush, Google
Analytics), freezes it as a snapshot, and publishes a private web page the practice opens from
a link. There are two surfaces: that **public report** (no login, token in the URL), and an
**admin panel** MSP staff log into. You are working only on the admin panel.

---

## Read this first

All paths are relative to the repository root. Read in this order.

| File | Why |
|---|---|
| `CLAUDE.md` | **How we write code here.** Binding, not advisory. Read the whole thing before your first commit — particularly *Controllers: actions only*, *Long methods*, *Testing*, and *Security* |
| `CONVENTIONS.md` | The Rails rulebook — mechanics. `CLAUDE.md` wins on structure, this wins on framework detail |
| `docs/features/admin-panel.md` | **The feature you are extending.** Its "Not built yet" list literally names *Admin user management* — your job is to delete that line |
| `docs/MSP-GUIDE.md` → *Logging in*, *Who can do what* | How MSP staff are told this works today. You will be rewriting both sections |
| `docs/reference/data-model.md` | Every table and column |
| `docs/README.md` | The documentation convention |

**Code to read before designing anything:**

- `app/models/admin_user.rb` — 20 lines, the whole current model
- `app/controllers/application_controller.rb` — `authenticate_admin!`, `require_editor!`, `current_admin_user`
- `app/controllers/sessions_controller.rb` — login and logout
- `lib/tasks/admin_users.rake` — today's account-creation path
- `app/controllers/connections_controller.rb` + `test/controllers/connections_controller_test.rb` — **the reference for role gating and for the security assertions we expect**
- `app/views/connections/index.html.erb`, `app/views/connections/edit.html.erb`, `app/views/shared/_admin_sidebar.html.erb`, `app/views/shared/_form_group.html.erb`, `app/views/shared/_alert.html.erb` — the visual and markup precedent to match

---

## Where things stand today

Authentication is hand-rolled and session-based — **not Devise, don't add it**. `AdminUser`
uses `has_secure_password`. `ApplicationController` runs `before_action :authenticate_admin!`
app-wide, so everything is protected unless it opts out; `require_editor!` is the write gate,
opted into per controller.

There are **two roles**, `admin` (can change API credentials and practices) and `support`
(view everything, change nothing), as `enum :role, { admin: "admin", support: "support" },
validate: true`.

What does not exist:

- **No way to create an account except a rake task** run by a developer:
  `ADMIN_EMAIL=... ADMIN_PASSWORD=... ADMIN_ROLE=admin bin/rails admin_users:create`
- **No invitation flow**, no password reset, no MFA, no session expiry, no audit log
- **No way to deactivate or remove an account** short of `AdminUser.destroy`
- **No mailer at all.** `app/mailers/application_mailer.rb` exists and nothing subclasses it.
  Nothing in this app has ever sent an email — see [The mailer problem](#the-mailer-problem)
- **No failed-login auditing and no rate limiting** on `/login`

---

## Scope

**In scope**

1. A **Team** page listing every admin account: name, email, role, status, when they were
   invited and by whom, when they last accepted.
2. **Invite by email** — an owner enters an email, a name, and a role. The invitee gets a
   single-use, expiring link, follows it, sets their own password, and lands logged in.
3. **Change a member's role.**
4. **Deactivate and reactivate** a member. Deactivating must end their access immediately, not
   at their next logout.
5. **Resend and revoke** a pending invitation.
6. Own account: **set your own name** and **change your own password**. (A member with a
   forgotten password still needs a developer — password reset by email is out of scope, see
   below.)
7. **Documentation updates** — same branch, same PR (`CLAUDE.md` → *Updating the
   documentation*). This is part of Done, not a follow-up.

**Explicitly out of scope**

- **Password reset / "forgot password"**. It is the obvious neighbour and it is deliberately
  excluded, so the branch stays reviewable. Build the invitation flow so a reset is later a
  second token type on the same machinery, and say so in the PR description.
- MFA, session expiry, a general audit log, per-practice access scoping.
- Anything on the public report.

---

## Roles — the recommendation

**Add exactly one role, `owner`, for a total of three. Do not build four.**

| | **owner** | **admin** | **support** |
|---|---|---|---|
| Invite, change roles, deactivate members | ✅ | — | — |
| Edit agency-wide API credentials (Connections) | ✅ | ✅ | — |
| Add, edit, offboard a practice | ✅ | ✅ | — |
| Edit a practice's per-service IDs | ✅ | ✅ | — |
| View Dashboard, Report Log, report links | ✅ | ✅ | ✅ |
| Change own name and password | ✅ | ✅ | ✅ |

**Why `owner` and why only `owner`:**

- **Inviting someone and setting their role is the only action in the system that can escalate
  privilege.** Everything else changes data; this changes who can change data. If `admin`
  could invite, any admin could mint themselves a second admin or promote a support user, and
  the role distinction that already exists would be decorative. That is a real separation, so
  it earns a real role.
- **`admin` and `support` keep exactly today's meaning.** No existing behaviour changes
  meaning, no existing test has to be reinterpreted, and `docs/MSP-GUIDE.md`'s "Who can do
  what" table gains a row rather than being rewritten.
- **A fourth role would be speculative.** The candidate is a `manager` — onboards practices,
  copies report links, but **cannot touch agency-wide API credentials**,
  because rotating an agency key breaks every practice's report while misconfiguring one
  practice breaks one. That is a genuine blast-radius difference and it may well be right for
  MSP. But nobody has told us MSP employs someone in that shape, and `CLAUDE.md` is explicit:
  no speculative generality, extract on the third occurrence not the second.

So: **build three roles, and write the permission checks so a fourth is one enum value plus one
row in a matrix** — never a rewrite. Concretely, gate on capability predicates rather than role
names:

```ruby
# app/models/admin_user.rb — names describe what the holder may do, not who they are
def can_manage_team?        = owner?
def can_manage_credentials? = owner? || admin?
def can_manage_practices?   = owner? || admin?
```

`require_editor!` then asks `can_manage_practices?`, the Connections gate asks
`can_manage_credentials?`, and adding `manager` later means adding it to one predicate. Put the
open question in the PR description so the user can take it to MSP: *does anyone onboard
practices who should not hold the agency API keys?*

**Naming:** `owner`, not `super_admin` or `superuser` — it reads correctly in the sidebar,
which renders `current_admin_user.role` capitalised straight into the UI.

---

## Data model

`role` is a **string** column, so adding `owner` to the enum needs **no migration**. Everything
else does. One migration, additive only.

| Column | Type | Notes |
|---|---|---|
| `status` | `string, null: false, default: "pending"` | Enum `pending` / `active` / `deactivated`, `validate: true` |
| `invited_by_id` | `bigint`, indexed, FK to `admin_users` | Nullable — the bootstrap account was invited by nobody |
| `invited_at` | `datetime` | |
| `accepted_at` | `datetime` | Null while pending; this and `status` are the audit trail |
| `deactivated_at` | `datetime` | |

Plus an index on `status` (you will filter the list by it).

**Prefer a `status` enum over the `discard` gem here.** `discard` is in the Gemfile and `Client`
uses it, but a deactivated colleague is a *visible state in a list*, not a soft-deleted row to
be hidden — and `pending` is a third state `discarded_at` cannot express. Three named states in
one column beats a boolean plus a timestamp.

### Five traps in this specific table

1. **`admin_users` does NOT use a UUID primary key.** Almost every table in this schema is
   `t.string :id, limit: 36` with `HasUuidPrimaryKey`, and `CLAUDE.md` tells you to follow that
   shape — but `admin_users` has a plain bigint `id` (see
   `db/migrate/20260728160020_create_admin_users.rb`), and `AdminUser` does not include the
   concern. **Do not "fix" this and do not follow the UUID pattern here.** `invited_by_id` is a
   `bigint`.
2. **`db/schema.rb` already declares `first_name` and `last_name` on this table, and no
   migration creates them.** They arrived in `db/schema.rb` in commit `42c5f37` with no
   migration behind them, and nothing in the app reads them. A fresh `db:migrate` from zero
   produces a table without them; `db:schema:load` produces one with them. **Resolve this in
   your branch** — you want a display name anyway, so the clean fix is a migration that adds
   the two columns for real, leaving schema and migrations consistent. Mention it in the PR;
   it is a pre-existing bug you are absorbing, not one you caused.
3. **Nobody is an `owner` after deploy.** Existing accounts are all `admin` or `support`, so
   the moment this ships, no one can reach the Team page. You need an explicit promotion step:
   extend `lib/tasks/admin_users.rake` with a `admin_users:promote` task
   (`ADMIN_EMAIL=... bin/rails admin_users:promote`), and change `admin_users:create`'s
   `ADMIN_ROLE` default from `admin` to `owner` so a fresh install bootstraps into a usable
   state. **Never do this in a migration** — `CLAUDE.md` forbids data changes in schema
   migrations, and every environment replays migrations.
4. **"At least one active owner" cannot be a database constraint.** Enforce it in the model and
   test it: refuse to deactivate, demote, or delete the last active owner, and refuse to let
   anyone demote or deactivate *themselves* (a self-lockout is the single most likely support
   ticket this feature will generate).
5. **Existing rows have `status` NULL** until backfilled. `null: false, default: "pending"`
   backfills existing rows to `pending`, which would lock out everyone who currently works.
   Set the default to `pending` for *new* rows but **backfill existing rows to `active`** — do
   the backfill in the same migration only if it is a plain `UPDATE` on a table of fewer than
   ten rows, which it is; otherwise follow `CLAUDE.md`'s add-nullable → backfill → constrain
   sequence. State which you chose and why in the migration comment.

---

## The invitation flow

Use Rails 8's **`generates_token_for`** rather than an invitation-token column:

```ruby
# app/models/admin_user.rb
generates_token_for :invitation, expires_in: 7.days do
  password_digest   # changes the moment they set a password, so the link is single-use
end
```

The token is signed, not stored, so there is no secret at rest, no column to leak, and
expiry and single-use both fall out of the design. `AdminUser.find_by_token_for(:invitation,
params[:token])` returns `nil` for expired, tampered, or already-accepted links — one code path
for every failure, and the same generic message for all of them.

**Route the acceptance page outside authentication**, the way `SessionsController` does it —
`skip_before_action :authenticate_admin!`, `layout "auth"`, reusing
`app/views/shared/_login_header.html.erb`. On success: set the password, set `status: "active"`
and `accepted_at`, `reset_session`, sign them in, redirect to the Dashboard.

**Treat the invite URL as a credential.** It grants admin-panel access to whoever holds it —
exactly the property that makes the public report token sensitive. Never log it (it will be a
path segment, and `filter_parameters` does not touch path segments — this is recorded as open
gap 5 in `CLAUDE.md` → Security), never render it in a flash that outlives the page, and never
email it to an address other than the invitee's.

### The mailer problem

**This app has never sent an email.** There is no mailer subclass, no SMTP configuration, and
`config/environments/production.rb:61` sets
`config.action_mailer.default_url_options = { host: "example.com" }` — so the first invite link
generated in production would point at `example.com`. `CLAUDE.md` already flags this as
something to fix before any send feature ships.

**Build it so the feature works before email does.** After creating an invitation, show the
inviting owner the invite link with a copy button, so they can send it themselves over whatever
channel they already use. Then add `AdminUserMailer#invitation` on top of that, and set the
real production host in the same branch. Two consequences to design for:

- The link is shown once, on the confirmation screen. Re-showing it later is a **resend**,
  which mints a fresh token, not a lookup of the old one.
- Delivery must not be able to fail the request. Deliver with `deliver_later`, and make sure a
  mail failure never rolls back the invitation — the copyable link is the fallback.

Ask the user before configuring an SMTP provider; that is an infrastructure decision, not
yours. If it is not settled by the time the rest is done, ship the copy-link path, leave the
mailer behind a "not configured" note, and say so in the PR.

---

## Traps in the existing code — read this section twice

**1. `require_editor!` will lock owners out of everything.** It is currently:

```ruby
def require_editor!
  unless current_admin_user&.admin?   # ← an owner is not admin?, so this fails closed
```

Adding a role *above* `admin` silently removes every write permission from it. Three call sites
break the moment you add the enum value:
`app/controllers/connections_controller.rb:6`, `app/controllers/clients_controller.rb:4`,
`app/controllers/client_service_links_controller.rb:8`. Replace the role-name check with the
capability predicates above, and add a test that an `owner` can edit a credential — there is no
such test today, because there is no such role.

**2. Deactivation must end the session immediately.** `current_admin_user` is
`AdminUser.find_by(id: session[:admin_user_id])`, so a deactivated user stays logged in and
fully privileged until they happen to log out. Scope that lookup to active users. A test that
deactivates a signed-in user and then asserts their next request redirects to login is
mandatory.

**3. A pending invitee must not be able to log in.** They have a row and no `password_digest`.
`SessionsController#create` does `AdminUser.find_by(email:)&.authenticate(password)`, and
`AdminUser` only validates password length `if: -> { password.present? }`, so the row saves
fine. Verify what `authenticate` does with a nil digest rather than assuming, then gate login
on `status == "active"` regardless. Test it.

**4. This is the right moment to extract the `Authentication` concern.** `CLAUDE.md` says
controllers contain actions and nothing else, names
`app/controllers/concerns/authentication.rb` as the destination for `current_admin_user` /
`authenticate_admin!` / `require_editor!`, and says to refactor the controller you are already
touching. You are touching all three methods, so do it — and stop there. Do not refactor
`ConnectionsController` or `ReportsController` in this branch.

**5. No private methods in your controllers.** Loading the member and the strong params go in a
concern (`FindsTeamMember`, alongside the existing `FindsClient` — read
`app/controllers/concerns/finds_client.rb` for the house shape). An action does at most
authorize, load, delegate, respond, in roughly five lines.

**6. Tailwind cannot see interpolated class names.** Role and status badges must map to
complete literal class strings. `AgencyConnection::DISPLAY` is the pattern; copy it. Never
build `bg-#{colour}-100`.

**7. `/login` has no rate limiting, and you are adding a second unauthenticated POST surface**
(accept-invite). Rails 8 ships `rate_limit to: 10, within: 3.minutes`. It needs a real cache
store and the test environment is `:null_store`, so a test asserting the limit must swap the
store in. Adding it to your new action is in scope; retrofitting `/login` is a separate concern
— raise it, don't smuggle it in.

---

## The screen

**Extend the existing design system; do not introduce a new visual language.** Tokens live in
`app/assets/tailwind/application.css`: `--color-teal-primary` `#0d9488` for primary actions and
active nav, `--color-teal-dark` `#0f766e` for links and hover, **slate** for every neutral
(`slate-50` page wash, `slate-900` headings, `slate-500` muted, `slate-200` borders),
**emerald** for success, **amber** for warning, **red** for failure. Cards are
`rounded-2xl border border-slate-200 bg-white p-5 shadow-sm`; controls `rounded-lg`. Page title
is `text-2xl font-semibold tracking-tight text-slate-900` with a `text-sm text-slate-500`
subtitle.

**Sidebar:** add a **Team** item to the array in `app/views/shared/_admin_sidebar.html.erb` and
a `team: :users` entry to `ADMIN_NAV_ICONS` in `app/helpers/application_helper.rb`. The `users`
icon already exists in `ICON_INNER` — **no new icon is needed, and adding one means editing
`ICON_INNER` in `app/helpers/reports_helper.rb`, never inlining SVG in a view.** Show the item
to everyone but make the page read-only for non-owners; do not hide the nav item, because a
silently missing link reads as a bug.

**States to design, not imply:**

- A member who is `active`, one `pending` (invited, not accepted), one `deactivated`
- **A pending invite whose link has expired** — visibly different from merely pending, because
  the fix is different: resend
- **The read-only state for `admin` and `support`** — visible, explained, not just controls
  removed. `CLAUDE.md` and the existing brief both require this
- **You, in the list** — your own row cannot be demoted or deactivated, and should say why
- **The last active owner's row** — same treatment, different reason
- Empty state: a fresh install with one bootstrap owner and nobody else

**Interaction rules:** server-rendered ERB with light Hotwire. Everything must work as plain
HTML — no JavaScript-only paths, Stimulus only for progressive enhancement (the copy-link
button is the obvious candidate, and it must degrade to a selectable text field). Full-page
forms redirect on success and `render ..., status: :unprocessable_entity` on failure; Turbo
needs the 422 to replace the form. Deactivate and revoke are destructive, so they are
`button_to` with a confirmation, never a `GET` link.

**Responsiveness:** the admin panel is desktop-first but must not break on a phone — MSP staff
do check it from one. Verify at 390px, 768px, 1280px with nothing overflowing horizontally. The
member table is the wide-content case; patterns for it are in
`docs/reference/design-system.md#responsiveness` — reuse them rather than inventing one.

**Accessibility:** real headings (`h1` page title, `h2` per card), status conveyed by text as
well as colour, `aria-hidden="true"` on icons that sit beside a text label, `text-slate-400`
never used for text a person has to read.

---

## Testing

`bin/ci` is the gate. Run it before you claim done: `rubocop`, `bundler-audit`, `importmap
audit`, `brakeman` (with `--exit-on-warn` locally — treat a warning as a failure), tests,
`db:seed:replant`, and `bin/rails docs:check`.

**This project does not use fixtures** — `test/fixtures/` is empty on purpose (UUID string PKs
and encrypted columns make fixtures actively wrong here). Build records in `setup` or a named
builder, and suffix unique columns so parallel workers cannot collide:
`"owner-#{SecureRandom.hex(4)}@example.com"`.

**Extract `sign_in_as` to `test/support/` first.** It is currently a private method at
`test/controllers/connections_controller_test.rb:84` where only one file can use it, and you
need it in at least three. `test/support/` exists, is empty, and **is not autoloaded** — add
the require to `test_helper.rb`:

```ruby
Dir[Rails.root.join("test/support/**/*.rb")].each { |f| require f }

class ActionDispatch::IntegrationTest
  include AuthenticationHelpers
end
```

**Required coverage, at minimum:**

| Area | Must assert |
|---|---|
| Role gates | Each of `owner` / `admin` / `support` against every new action — and that `owner` can still edit a credential and a practice (the `require_editor!` regression) |
| Invitation | Valid token accepts; expired, tampered, and already-used tokens all fail the same way; a pending invitee cannot log in |
| Deactivation | A signed-in user who is deactivated is redirected to login on their **next** request |
| Invariants | Cannot demote or deactivate yourself; cannot remove the last active owner |
| Security | **The invite token never appears in a response body, flash, or log where it shouldn't** — model it on `connections_controller_test`'s `assert_no_match(/super-secret-token/, response.body)`, which is non-negotiable for any new credential surface |
| Model | The `status` enum, the `role` enum including `owner`, email downcasing, password minimum length |
| Mailer | If you build it: enqueued, addressed to the invitee, and the link points at the configured host |

Assert on **user-visible content**, not markup structure — `assert_select "td", text: "Pending"`
survives a restyle; a class-chain selector does not. Use `travel_to` for token expiry; never
`sleep`.

**One warning:** `test_helper.rb:7` is `WebMock.disable_net_connect!` with no
`allow_localhost: true`, so the first Capybara system test anyone writes fails with
`WebMock::NetConnectNotAllowedError` rather than a real failure. If you write a system test for
the invite flow, fix that line first — it still blocks every external API, since localhost is
the test server.

---

## Documentation — part of Done, same PR

`bin/rails docs:check` runs in CI and **fails the build if a source file is not named in a
document's Key files table**, so this is a hard gate, not a nicety. Every file you add needs a
row.

| Document | What changes |
|---|---|
| `docs/features/admin-panel.md` | Roles table gains `owner`; *How it behaves* gains the Team page and the invitation flow; **delete "Admin user management" from *Not built yet***; add every new file to *Key files*; add the new columns to *Data*; add the new gotchas; bump `last_verified` **only if you re-read the document against the code** |
| `docs/MSP-GUIDE.md` | *Logging in* — no longer "accounts are created by a developer"; document inviting someone, and keep the rake task documented as the **bootstrap** path. *Who can do what* — three roles. Move account creation **out of the "Needs a developer" framing**, which `CLAUDE.md` requires whenever UI replaces a command |
| `docs/reference/data-model.md` | The new `admin_users` columns and the `status` enum |
| `docs/reference/design-system.md` | Only if you add a genuinely new component |

Write the prose **once the code has stopped moving**, not per commit — and read the current
code rather than what you remember writing. Capture facts as you learn them in the meantime.

---

## Definition of done

1. `bin/ci` passes.
2. Tests cover the table above, including the `owner`-can-still-write regression and the
   secret-never-echoed assertion.
3. No private methods in any controller you add; no method over ~10 lines; every method passes
   `CLAUDE.md`'s naming test.
4. `db/schema.rb` committed with the migration; the `first_name` / `last_name` drift resolved.
5. Views verified at 390px / 768px / 1280px, with real headings and status conveyed by more
   than colour.
6. No invite token in a log, a rendered response it doesn't belong in, or a plaintext column.
7. The bootstrap path works: a fresh install can create an owner, and the existing production
   account can be promoted without a migration.
8. `docs/features/admin-panel.md` and `docs/MSP-GUIDE.md` updated in this PR.
9. Non-obvious decisions carry a *why* comment.

---

## Questions to settle before you build — ask, don't assume

1. **Three roles or four?** The `manager` case is argued above. Needs MSP's answer on whether
   anyone onboards practices who should not hold the agency API keys.
2. **SMTP provider for the invitation email**, and the real production hostname for
   `default_url_options`. Until both exist, the copy-the-link path is the shipping path.
3. **Invitation lifetime** — 7 days is proposed. MSP may want shorter.
4. **Who is the initial owner?** Someone has to name the account to promote.
5. **Does MSP want to see failed logins or an access log?** Out of scope as written, but this
   is the branch where the question naturally arises.

---

## Copy conventions

Sentence case throughout. No em-dashes or smart punctuation in interface strings. Verb-first
for actions ("Invite member", "Deactivate"). In anything MSP-facing say **"practice"**, not
"client" — "client" is ambiguous between the dental practice and MSP itself. Say **"member"**
or **"team member"**, not "user", in the Team page's own copy.
