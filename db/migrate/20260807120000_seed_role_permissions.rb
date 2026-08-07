# frozen_string_literal: true

# Deliberate exception to "no data changes in a schema migration"
# (CONVENTIONS.md §3): the client flagged role_permissions as critical data
# that must exist the moment the app boots, not something that can wait on a
# separate deploy step. This mirrors the belt-and-suspenders precedent
# CreateRoles/CreatePermissions already set for roles/permissions themselves
# — seeded here for a full migration replay, and still separately seeded
# (idempotently) in db/seeds.rb for the schema:load-then-seed path
# db:prepare actually takes on a fresh boot (see bin/docker-entrypoint).
# Keep both in sync; don't delete the db/seeds.rb block in favor of this one.
class SeedRolePermissions < ActiveRecord::Migration[8.1]
  class Role < ActiveRecord::Base; end
  class RolePermission < ActiveRecord::Base; end

  # Mirrors Role::DEFAULT_PERMISSIONS as of this migration's authoring —
  # inlined, not referenced, so this migration stays stable against future
  # changes to that constant (same reasoning as CreateServices/CreateRoles).
  ALL_PERMISSION_KEYS = %w[
    clients_view clients_create clients_edit clients_delete
    dashboard_view
    reports_view reports_generate
    report_logs_view
    connections_view connections_edit
    users_view users_invite users_edit users_remove
    roles_manage
  ].freeze

  SEED_ROLE_PERMISSIONS = {
    "super_admin" => ALL_PERMISSION_KEYS,
    "admin" => ALL_PERMISSION_KEYS - %w[clients_delete roles_manage],
    "account_manager" => %w[clients_view dashboard_view reports_view reports_generate]
  }.freeze

  def change
    reversible do |dir|
      dir.up do
        SEED_ROLE_PERMISSIONS.each do |role_key, permission_keys|
          role = Role.find_by!(key: role_key)
          permission_keys.each do |permission_key|
            RolePermission.find_or_create_by!(role_id: role.id, permission_key: permission_key)
          end
        end
      end
    end
  end
end
