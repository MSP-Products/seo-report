# frozen_string_literal: true

# A role's default permission grants. No rows seeded here — the default
# role->permission mapping (Role::DEFAULT_PERMISSIONS) is business data, not
# FK-dependent reference data, so it belongs in db/seeds.rb, never a migration.
class CreateRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :role_permissions do |t|
      t.bigint :role_id, null: false
      t.string :permission_key, null: false
      t.timestamps
    end

    add_index :role_permissions, [ :role_id, :permission_key ], unique: true, name: "idx_role_permissions_unique"
    add_foreign_key :role_permissions, :roles
    add_foreign_key :role_permissions, :permissions, column: :permission_key, primary_key: :key
  end
end
