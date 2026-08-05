# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
