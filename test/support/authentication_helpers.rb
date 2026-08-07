# frozen_string_literal: true

module AuthenticationHelpers
  def sign_in_as(role: "admin")
    admin = AdminUser.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123",
      first_name: "Test", last_name: "User", role: Role.find_by!(key: role)
    )
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
