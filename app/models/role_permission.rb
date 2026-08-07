# frozen_string_literal: true

class RolePermission < ApplicationRecord
  belongs_to :role
  belongs_to :permission, foreign_key: :permission_key, inverse_of: :role_permissions

  validates :permission_key, uniqueness: { scope: :role_id }
end
