# frozen_string_literal: true

# Per-user override on top of the role's default grants — the "hybrid" half of
# the RBAC model. granted: true adds a permission the role doesn't include;
# granted: false revokes one the role does include.
class CreateAdminUserPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_user_permissions do |t|
      t.bigint :admin_user_id, null: false
      t.string :permission_key, null: false
      t.boolean :granted, null: false
      t.timestamps
    end

    add_index :admin_user_permissions, [ :admin_user_id, :permission_key ], unique: true,
      name: "idx_admin_user_permissions_unique"
    add_foreign_key :admin_user_permissions, :admin_users
    add_foreign_key :admin_user_permissions, :permissions, column: :permission_key, primary_key: :key
  end
end
