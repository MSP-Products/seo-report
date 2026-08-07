require "test_helper"

class TeamMemberResenderTest < ActiveSupport::TestCase
  test "regenerates the password for a member who has never logged in" do
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "old-password-123",
      role: Role.find_by!(key: "account_manager"))

    result = TeamMemberResender.new(admin_user: member).call

    assert result.errors.empty?
    assert_not_nil result.generated_password
    assert member.reload.authenticate(result.generated_password)
    assert_not member.authenticate("old-password-123")
  end

  test "refuses once the member has logged in" do
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "original-password",
      role: Role.find_by!(key: "account_manager"))
    member.touch_last_active

    result = TeamMemberResender.new(admin_user: member).call

    assert result.errors[:base].any?
    assert member.reload.authenticate("original-password")
  end
end
