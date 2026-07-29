# frozen_string_literal: true

class AdminUser < ApplicationRecord
  has_secure_password

  # Enums
  enum :role, { admin: "admin", support: "support" }, validate: true

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  # Callbacks
  before_validation :downcase_email

  private

  def downcase_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
