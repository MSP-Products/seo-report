# frozen_string_literal: true

class Permission < ApplicationRecord
  self.primary_key = "key"

  KEYS = %w[
    clients_view clients_create clients_edit clients_delete
    dashboard_view
    reports_view reports_generate
    report_logs_view
    connections_view connections_edit
    users_view users_invite users_edit users_remove
    roles_manage
    user_permissions_manage
  ].freeze

  has_many :role_permissions, foreign_key: :permission_key, inverse_of: :permission, dependent: :destroy
  has_many :admin_user_permissions, foreign_key: :permission_key, inverse_of: :permission, dependent: :destroy

  validates :key, presence: true
end
