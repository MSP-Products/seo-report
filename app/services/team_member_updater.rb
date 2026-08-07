# frozen_string_literal: true

# Updates a team member's name/email/role.
class TeamMemberUpdater
  def initialize(admin_user:, attrs:, actor:)
    @admin_user = admin_user
    @attrs = attrs
    @actor = actor
  end

  def call
    AdminUser.transaction do
      admin_user.assign_attributes(attrs)
      next admin_user if blocked_super_admin_assignment?

      admin_user.save
      admin_user
    end
  end

  private

  attr_reader :admin_user, :attrs, :actor

  # Same enforcement point as TeamMemberInviter — only a Super Admin may
  # assign the Super Admin role. The last-Super-Admin case (can't move
  # *away* from Super Admin) is a separate, model-level guard.
  def blocked_super_admin_assignment?
    return false unless admin_user.role_id == Role.super_admin.id
    return false if actor.role_id == Role.super_admin.id

    admin_user.errors.add(:role_id, "can only be assigned by a Super Admin")
    true
  end
end
