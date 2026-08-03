# Creating an admin account is a one-off operational task, not schema — it must
# never go in a migration (every environment replays migrations, and the
# password would sit in source control forever). Credentials come from ENV
# only — never hardcode a real email or password here, this file is committed.
namespace :admin_users do
  desc "Create an admin account: ADMIN_EMAIL=... ADMIN_PASSWORD=... [ADMIN_ROLE=admin] bin/rails admin_users:create"
  task create: :environment do
    email = ENV.fetch("ADMIN_EMAIL")
    role = ENV.fetch("ADMIN_ROLE", "admin")

    admin = AdminUser.create!(email: email, password: ENV.fetch("ADMIN_PASSWORD"), role: role)
    puts "Created #{admin.role} account: #{admin.email}"
  end
end
