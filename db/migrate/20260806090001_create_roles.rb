# frozen_string_literal: true

# Real, mutable rows (not a lookup table like Service) — a Super Admin can
# create/edit/delete roles later, so this needs identity that survives a
# rename, not a fixed enum-style key-as-primary-key table.
class CreateRoles < ActiveRecord::Migration[8.1]
  class Role < ActiveRecord::Base; end

  SEED_ROLES = [
    { key: "super_admin", name: "Super Admin" },
    { key: "admin", name: "Admin" },
    { key: "account_manager", name: "Account Manager" }
  ].freeze

  def change
    create_table :roles do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :roles, :key, unique: true

    # Seeded here (not just db/seeds.rb) because admin_users.role_id, added later
    # in this same PR, depends on these 3 rows existing.
    reversible { |dir| dir.up { SEED_ROLES.each { |attrs| Role.create!(attrs) } } }
  end
end
