# frozen_string_literal: true

# Which clients an Account Manager is responsible for — the "assigned clients"
# scope. client_id is a plain string FK column (not add_reference) because
# clients uses a UUID string primary key, per CONVENTIONS.md's UUID table shape.
class CreateAdminUserClientAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_user_client_assignments do |t|
      t.bigint :admin_user_id, null: false
      t.string :client_id, limit: 36, null: false
      t.timestamps
    end

    add_index :admin_user_client_assignments, [ :admin_user_id, :client_id ], unique: true,
      name: "idx_admin_user_client_assignments_unique"
    add_foreign_key :admin_user_client_assignments, :admin_users
    add_foreign_key :admin_user_client_assignments, :clients
  end
end
