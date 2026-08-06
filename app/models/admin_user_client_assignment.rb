# frozen_string_literal: true

class AdminUserClientAssignment < ApplicationRecord
  belongs_to :admin_user
  belongs_to :client

  validates :client_id, uniqueness: { scope: :admin_user_id }
end
