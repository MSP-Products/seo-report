# frozen_string_literal: true

# Step 1 of the role string -> role_id FK migration: add everything nullable.
# role_id gets its NOT NULL constraint in a later migration, once
# AdminRoleBackfill has run in every environment (see lib/tasks/team.rake).
#
# first_name/last_name are guarded with a column_exists? check: db/schema.rb
# on main already declares them (someone added them there directly, with no
# matching migration — confirmed by grepping every migration file), so a
# database built via db:schema:load already has them, while one built by
# replaying migrations from scratch does not. This migration reconciles both
# starting states instead of failing on whichever one already has the column.
class AddTeamColumnsToAdminUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :admin_users, :role, foreign_key: true, index: true
    add_column :admin_users, :first_name, :string unless column_exists?(:admin_users, :first_name)
    add_column :admin_users, :last_name, :string unless column_exists?(:admin_users, :last_name)
    add_column :admin_users, :last_active_at, :datetime
    add_column :admin_users, :discarded_at, :datetime
    add_index :admin_users, :discarded_at
  end
end
