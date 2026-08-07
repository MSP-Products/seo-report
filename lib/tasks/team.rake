# A one-off data migration, not schema — must never go in a migration (see
# AdminRoleBackfill for why). Required manual deploy step: run this against
# every environment with pre-existing admin_users rows (including production)
# before AddNotNullToAdminUsersRoleId's migration runs there, or that
# migration fails outright on any row still missing a role_id.
namespace :team do
  desc "One-off: backfill admin_users.role_id from the legacy role string"
  task backfill_roles: :environment do
    AdminRoleBackfill.new.call
    puts "Backfilled #{AdminUser.where.not(role_id: nil).count} admin_users row(s)."
  end
end
