# frozen_string_literal: true

class Role < ApplicationRecord
  SUPER_ADMIN = "super_admin"
  ADMIN = "admin"
  ACCOUNT_MANAGER = "account_manager"

  # Single source of truth for each built-in role's default grants — read by
  # db/seeds.rb (and test_helper.rb) to populate role_permissions.
  DEFAULT_PERMISSIONS = {
    SUPER_ADMIN => Permission::KEYS,
    ADMIN => Permission::KEYS - %w[clients_delete roles_manage],
    ACCOUNT_MANAGER => %w[clients_view dashboard_view reports_view reports_generate]
  }.freeze

  has_many :admin_users, dependent: :restrict_with_error
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions

  validates :key, :name, presence: true
  validates :key, uniqueness: true

  def self.super_admin
    find_by!(key: SUPER_ADMIN)
  end
end
