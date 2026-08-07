# frozen_string_literal: true

# Fixed lookup table, same shape as Service (db/migrate/20260731210000_create_services.rb)
# — every value here is a capability defined in code, not something a user
# creates through the UI, unlike Role.
class CreatePermissions < ActiveRecord::Migration[8.1]
  class Permission < ActiveRecord::Base
    self.primary_key = "key"
  end

  PERMISSION_KEYS = %w[
    clients_view clients_create clients_edit clients_delete
    dashboard_view
    reports_view reports_generate
    report_logs_view
    connections_view connections_edit
    users_view users_invite users_edit users_remove
    roles_manage
    user_permissions_manage
  ].freeze

  def change
    create_table :permissions, id: false do |t|
      t.string :key, primary_key: true
      t.timestamps
    end

    reversible { |dir| dir.up { PERMISSION_KEYS.each { |key| Permission.create!(key: key) } } }
  end
end
