---
title: Team
slug: team
status: partial
last_verified: 2026-08-06
related: [admin-panel]
---

# Team

> **Status:** partial — the team list is real and read-only; nothing writes yet ·
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

### When data is missing

Not applicable — every team member row reads real columns; there's no external data
source to degrade.

### FAQ

**Q: Can I invite a team member yet?**
A: Not yet. Accounts are still created by a developer, the same as before this module
started. You can see who currently has access, though.

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
| `app/controllers/team_members_controller.rb` | The team list — `index` only so far |
| `app/helpers/team_members_helper.rb` | Permission display labels, role badge classes, viewer-relative status/last-active labels |
| `app/views/team_members/index.html.erb` | The team list and per-role permission summary cards |
| `app/views/shared/_admin_sidebar.html.erb` | Team now links to the real page instead of Connections |

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
| Account Manager visits `/team` | Redirect to the dashboard | Nothing |

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

### Not built yet

- Any write UI — invite, manage, remove, resend. The list is read-only.
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
