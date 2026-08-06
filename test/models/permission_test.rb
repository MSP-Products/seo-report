require "test_helper"

class PermissionTest < ActiveSupport::TestCase
  test "KEYS matches the seeded rows" do
    assert_equal Permission::KEYS.sort, Permission.pluck(:key).sort
  end

  test "key is required" do
    permission = Permission.new

    assert_not permission.valid?
    assert_includes permission.errors[:key], "can't be blank"
  end
end
