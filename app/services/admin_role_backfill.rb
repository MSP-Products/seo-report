# frozen_string_literal: true

# One-off: maps the legacy string admin_users.role ("admin"/"support") onto
# the new roles table, and stamps last_active_at for accounts already in
# active use so they don't show as freshly "Invited" the moment this ships.
# Idempotent (skips any row that already has role_id set) — safe to re-run in
# every environment, including production, where it must be run manually
# before AddNotNullToAdminUsersRoleId (see lib/tasks/team.rake).
class AdminRoleBackfill
  MAPPING = { "admin" => "super_admin", "support" => "account_manager" }.freeze

  def call
    AdminUser.where(role_id: nil).find_each { |admin_user| backfill(admin_user) }
  end

  private

  def backfill(admin_user)
    # admin_user.role now resolves the belongs_to :role association (nil,
    # since role_id is what we're backfilling) — the legacy string column of
    # the same name is only reachable through the raw attribute reader.
    legacy_role = admin_user[:role]
    role_key = MAPPING.fetch(legacy_role) { raise "Unmapped legacy role: #{legacy_role.inspect}" }
    admin_user.update_columns(role_id: Role.find_by!(key: role_key).id, last_active_at: Time.current)
  end
end
