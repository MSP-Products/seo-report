# frozen_string_literal: true

class AdminUser < ApplicationRecord
  has_secure_password

  # Enums
  enum :role, { admin: "admin", support: "support" }, validate: true

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
