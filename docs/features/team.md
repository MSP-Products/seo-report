---
title: Team
slug: team
status: partial
last_verified: 2026-08-06
related: [admin-panel]
---

# Team

> **Status:** partial — listing, inviting, managing, removing, and resending all work ·
> **Last verified:** 2026-08-06
>
> Lets authorized MSP staff invite and manage their own colleagues' accounts and access,
> replacing developer-run console commands.

---

## For everyone

### Purpose

Today, creating or changing an admin account requires a developer running a console
command or rake task. Team will let an authorized staff member invite a new colleague,
assign them a role, and adjust their access, without a developer in the loop.

### Who uses it

MSP staff only, once built. Three roles are planned:

| Role | Can |
|---|---|
| **Super Admin** | Everything Admin can, plus manage roles/permissions and delete clients |
| **Admin** | Day-to-day management: clients, connections, reports, and inviting/editing/removing other users |
| **Account Manager** | View and generate reports only for clients specifically assigned to them |

Every account also carries individual permission overrides on top of its role's defaults,
so a one-off exception never requires a new role.

### How it behaves

1. A Super Admin or Admin clicks **Team** in the sidebar.
2. The page lists every team member: name, email, role, last active time, and status
   (**You** for the viewer's own row, **Active** once someone has logged in, **Invited**
   if they haven't yet — though nothing can invite anyone yet, see below).
3. Below the list, one summary card per role shows how many members hold it and exactly
   which permissions it grants.
4. An Account Manager who visits `/team` directly is redirected away — this page isn't
   part of their role.
5. A Super Admin or Admin clicks **+ Invite member**, enters an email, name, and role, and
   submits.
6. The account is created immediately with a random password. The next screen shows that
   password **once** — there's no email delivery yet, so whoever invited them has to share
   it directly. Leaving that screen means it's gone for good from the app's side.
7. Only a Super Admin can invite someone in as a Super Admin — an Admin doesn't see that
   option on the form, and submitting it anyway (e.g. by hand-crafting the request) is
   rejected server-side too.
8. Clicking **Manage** on any row opens an edit page: name, email, and role are always
   there; a Super Admin also sees a checklist of every individual permission, pre-ticked
   to match what the member can currently do, so ticking or unticking one is an explicit
   exception on top of their role. If the member is an Account Manager, a third section
   lists every client, letting a Super Admin or Admin pick which ones they're responsible
   for.
9. The same Super-Admin-only rule applies here too — an Admin can change someone's role to
   anything except Super Admin, on the form and server-side both.
10. Clicking **Remove** on a row asks for confirmation, then removes that person — they
    disappear from the list immediately and can no longer log in. Their row and any past
    activity aren't deleted from the database, just hidden.
11. The very last Super Admin can't be removed this way — the page reloads with an error
    instead, so there's always at least one account able to manage roles and permissions.
12. **Resend** appears next to a member's row only while they've never logged in. Clicking
    it throws away their old password, generates a new one, and shows it once — same
    one-time-only rule as the original invite. Once someone has actually logged in, Resend
    disappears from their row; there's no way to force a password reset on an active
    account from here today.

### When data is missing

Not applicable — every team member row reads real columns; there's no external data
source to degrade.

### FAQ

**Q: Can I invite a team member yet?**
A: Yes — click **+ Invite member** on the Team page. You'll see their password once on the
next screen; make sure you copy it before navigating away, since there's no way to see it
again from the app.

**Q: I lost the password I was shown. Now what?**
A: If that person hasn't logged in yet, click **Resend** on their row — it generates a new
password and shows it once, the same way the original invite did. If they've already
logged in, there's no self-service reset yet; a developer would need to set a new password
directly.

---

## For developers

### How it works

This PR lays the schema and model foundation only:

- `Role` — real, mutable rows (not a fixed lookup table) so a Super Admin can create/edit
  custom roles later. Seeded with `super_admin`, `admin`, `account_manager`.
- `Permission` — a fixed lookup table (same shape as `Service`) of every capability the
  system can gate.
- `RolePermission` — a role's default permission grants.
- `AdminUserPermission` — per-user overrides on top of the role default (the hybrid part
  of the RBAC model): `granted: true` adds a permission the role doesn't include,
  `granted: false` revokes one it does.
- `AdminUserClientAssignment` — which clients an Account Manager is responsible for.
- `AdminUser#admin?`/`#support?` are now computed from the new role system instead of the
  old `role` enum, but return identical results for every migrated account, so
  `ClientsController`'s and `ConnectionsController`'s `require_editor!` needed no changes.
  `AdminUser#can?(permission_key)` is the new, permission-level check.
- `AdminRoleBackfill` maps existing `admin`/`support` string roles onto `Super Admin`/
  `Account Manager`. It's a one-off data migration, not schema, so it lives in
  `lib/tasks/team.rake` (`bin/rails team:backfill_roles`), never inside a migration.

`TeamMembersController#index` is the first real page: `AdminUser.kept.includes(:role)`,
gated by `require_permission!(:users_view)` (Super Admin and Admin have it by default;
Account Manager doesn't). `TeamMembersHelper` owns the view-only concerns the models
shouldn't: `PERMISSION_LABELS` (friendly copy for a `Permission#key`), role badge classes,
and the viewer-relative status/last-active labels (status depends on who's looking, not
just the record, so it's a helper, not a model method).

`TeamMembersController#new`/`#create` are the invite flow, gated by
`require_permission!(:users_invite)`. `#create` delegates to `TeamMemberInviter`
(`attrs:`, `actor:`), which generates a `SecureRandom.alphanumeric(16)` password, sets it
as both `password` and the transient `generated_password`, and — the one place the
Super-Admin-only rule is actually enforced — refuses to save if the target role is Super
Admin and the inviting `actor` isn't one themselves. `CredentialDelivery` is the single,
deliberately-empty seam real email/HubSpot delivery will eventually plug into.
`AdminUser#assignable_roles` keeps the form's visible role options honest (hides "Super
Admin" from anyone but a Super Admin) — cosmetic only, `TeamMemberInviter`'s check is the
real boundary. On success, `#create` **renders** `created.html.erb` rather than
redirecting, so the one-time password never has to survive a round-trip through anywhere
else (a session flash, a redirect param) that could leak or persist it.

`TeamMembersController#edit`/`#update` are Manage, gated by `require_permission!(:users_edit)`.
`#update` delegates to `TeamMemberUpdater` (`admin_user:`, `attrs:`, `actor:`,
`permission_overrides:`, `client_ids:`), same Super-Admin-only guard as the inviter. The
controller only reads `permission_overrides` from params when
`current_admin_user.can?(:user_permissions_manage)` — an Admin's request simply never
looks at that key, so hand-crafting it changes nothing; this is the actual enforcement
point, the edit view hiding the section is cosmetic. Each permission checkbox means
"should this be effectively granted" — `TeamMemberUpdater` diffs that against the (possibly
just-changed) role's own defaults and only ever stores the difference: matching the
default removes any override row, differing creates or updates one. Client assignment
follows the same shape: `client_ids: nil` (the field wasn't submitted at all, e.g. the
member isn't an Account Manager) leaves existing assignments untouched, while an empty
array explicitly clears them — the view guarantees an empty submission is `[]` not absent
via a leading hidden `client_ids[]` field, matching Rails' own checkbox-collection idiom.

`TeamMembersController#destroy` is Remove, gated by `require_permission!(:users_remove)`.
It's a one-liner calling `admin_user.discard` directly — no dedicated service, since
wrapping a single gem call would just be a layer to hold one method (mirrors
`ClientOffboardingsController`'s shape for the same reason). The last-Super-Admin guard
lives entirely on the model (`AdminUser`'s `before_discard` callback, see PR1) and applies
here automatically; the controller just surfaces whatever error it left on the record.
`AdminUser.kept` already excludes discarded rows everywhere that matters — the index list,
login, and `current_admin_user` — so removing someone is immediate and complete from the
app's point of view without any row actually being deleted.

`TeamMembersController#resend` shares `require_permission!(:users_invite)` with the invite
flow — resending is conceptually "invite them again," not a distinct permission. It
delegates to `TeamMemberResender` (`admin_user:`), which refuses (`errors.add(:base, ...)`)
once `last_active_at` is present — resend is only for someone who was invited but never
actually logged in; a genuine password reset for an active account is a different,
not-yet-built feature. On success it generates a fresh `SecureRandom.alphanumeric(16)`
password the same way `TeamMemberInviter` does and **renders** `resent.html.erb` rather
than redirecting, for the same one-time-secret reason `#create` does. Both `created.html.erb`
and `resent.html.erb` render the shared `_credentials.html.erb` partial — only the heading
above it differs ("was invited" vs. "New password for").

### Key files

| Path | Role in this feature |
|---|---|
| `app/models/role.rb` | The role entity, and `DEFAULT_PERMISSIONS` — the single source of truth for each built-in role's default grants |
| `app/models/permission.rb` | Fixed lookup of every gateable capability (`KEYS`) |
| `app/models/role_permission.rb` | A role's default permission grants |
| `app/models/admin_user_permission.rb` | Per-user permission override, on top of the role default |
| `app/models/admin_user_client_assignment.rb` | Which clients an Account Manager is responsible for |
| `app/models/admin_user.rb` | `can?`, `admin?`/`support?` (legacy-compatible), `invited?`, `display_name`, last-Super-Admin guards |
| `app/services/admin_role_backfill.rb` | Maps legacy string roles onto the new role system |
| `lib/tasks/team.rake` | `team:backfill_roles` — the required manual deploy step before the eventual `role_id` NOT NULL migration |
| `lib/tasks/admin_users.rake` | Updated to resolve `ADMIN_ROLE` to a `Role` record |
| `app/controllers/application_controller.rb` | `require_permission!`, `touch_admin_user_last_active` — additive only |
| `test/support/authentication_helpers.rb` | Shared `sign_in_as(role_key:)` test builder |
| `app/controllers/team_members_controller.rb` | The team list, plus `new`/`create` for the invite flow |
| `app/helpers/team_members_helper.rb` | Permission display labels, role badge classes, viewer-relative status/last-active labels |
| `app/views/team_members/index.html.erb` | The team list and per-role permission summary cards |
| `app/views/team_members/new.html.erb` | The invite form |
| `app/views/team_members/created.html.erb` | The one-time credentials screen |
| `app/views/shared/_admin_sidebar.html.erb` | Team now links to the real page instead of Connections |
| `app/services/team_member_inviter.rb` | Creates the account, generates the password, enforces the Super-Admin-only assignment rule |
| `app/services/credential_delivery.rb` | The swappable seam for real credential delivery, currently a no-op |
| `app/models/admin_user.rb` | `assignable_roles` — keeps the invite/edit forms' visible role options honest |
| `app/services/team_member_updater.rb` | Manage: details, role, permission-override diffing, client-assignment sync, the same Super-Admin-only guard |
| `app/views/team_members/edit.html.erb` | The Manage page's three conditional sections |
| `app/services/team_member_resender.rb` | Regenerates a password for a never-logged-in member; refuses otherwise |
| `app/views/team_members/_credentials.html.erb` | The one-time credentials display, shared by invite and resend |
| `app/views/team_members/resent.html.erb` | The resend screen, reusing the shared credentials partial |

### Data

| Model / table | What it holds here |
|---|---|
| `roles` | `key`, `name` — real rows, editable later |
| `permissions` | `key` — fixed, code-defined |
| `role_permissions` | `role_id`, `permission_key` |
| `admin_user_permissions` | `admin_user_id`, `permission_key`, `granted` |
| `admin_user_client_assignments` | `admin_user_id`, `client_id` |
| `admin_users` | Added `role_id` (FK, nullable for now — see Gotchas), `last_active_at`, `discarded_at`. `first_name`/`last_name` already existed on `main` with no matching migration; this PR's migration adds them idempotently (`unless column_exists?`) so it works whichever starting state a database is in. |

### Failure modes

| Failure | User sees | Recorded in |
|---|---|---|
| Not logged in | Redirect to login | Nothing |
| Account Manager visits `/team` or `/team/new` | Redirect to the dashboard | Nothing |
| An Admin submits a Super Admin invite anyway | 422, form re-rendered with an error, nothing created | Nothing |
| Invite form has any other validation error (blank email, etc.) | 422, form re-rendered | Nothing |
| An Admin tries to promote someone to Super Admin via Manage | 422, form re-rendered with an error | Nothing |
| Manage form has any other validation error | 422, form re-rendered | Nothing |
| Removing the last Super Admin | Redirect back to the list with an error, nothing removed | Nothing |
| Resending for a member who has already logged in | Redirect back to the list with an error, password unchanged | Nothing |

### Gotchas

- **`admin_users.role_id` is deliberately still nullable.** The `NOT NULL` constraint is
  its own later migration, added only once `bin/rails team:backfill_roles` has been
  confirmed run in every environment (including production) — bundling it into this PR
  made it untestable, since a schema-loaded test database gets the constraint immediately
  and there's no way to construct a not-yet-backfilled row to test the backfill against.
- **`admin_users.role` (legacy string column) still exists.** It's dropped in a later,
  separate migration. Because `AdminUser` now also has `belongs_to :role`, the association
  method shadows the raw column — `admin_user.role` returns the association (`nil` until
  backfilled), not the legacy string. `AdminRoleBackfill` reads it via `admin_user[:role]`.
- **`db/schema.rb` on `main` already had `first_name`/`last_name`** with no migration ever
  adding them — someone edited the schema file directly. A database built by replaying
  migrations from scratch (rather than `db:schema:load`) was actually missing them.

- **The generated password is never persisted anywhere except the hashed
  `password_digest`.** `AdminUser#generated_password` is an `attr_accessor`, not a column —
  it only survives for the lifetime of the request that created it. There is deliberately
  no way to recover it later, from the database or otherwise.
- **The assigned-clients section's visibility is decided at page load, from the member's
  *current* role** — changing the role dropdown and the assigned-clients checkboxes in the
  same submission works server-side (both are just params), but the section won't
  dynamically show or hide client-side without a page reload. No JS wires this up yet.
- **`test/test_helper.rb`'s `parallelize` threshold is now 1000, not 200.** The Team suite
  crossed 200 tests while this module was being built, and `parallelize` forks worker
  processes — `fork()` is unimplemented outright on Windows (not merely flaky, as the
  original comment's IPC issue was on other platforms). Raised again for the same reason
  the first bump gave: fragility outweighing parallel speed at this suite size.

### Not built yet

- A real password reset for a member who has already logged in.
- Reactivating a removed member — `discard` provides `#undiscard` for free, but no UI calls
  it, since nothing in the mockup this was built against shows a "removed" or "reactivate"
  state.
- Enforcing Account Manager's client-assignment scope in Clients/Dashboard/Reports.
- Custom role creation/editing (Super Admin capability, later phase).
- Real credential delivery on invite (no mailer is wired anywhere in this app yet).
- The `role_id` `NOT NULL` constraint and dropping the legacy `role` column.

---

## Changing this feature

- **Never bundle a `NOT NULL` constraint into the same PR as the backfill it depends on** —
  see Gotchas. Add it only once the backfill is confirmed run everywhere.
- **`AdminUser#admin?`/`#support?` must keep returning identical results** for every
  existing account. `ClientsController` and `ConnectionsController` depend on this being
  true without needing any changes of their own.
