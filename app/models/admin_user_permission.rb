# frozen_string_literal: true

class AdminUserPermission < ApplicationRecord
  belongs_to :admin_user
  belongs_to :permission, foreign_key: :permission_key, inverse_of: :admin_user_permissions

  validates :permission_key, uniqueness: { scope: :admin_user_id }
end
