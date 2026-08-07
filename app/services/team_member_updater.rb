# frozen_string_literal: true

# Updates a team member's name/email/role, and — only when the controller
# passes them (gated on the actor's own permissions) — their per-permission
# overrides and, for an Account Manager, their assigned clients.
class TeamMemberUpdater
  def initialize(admin_user:, attrs:, actor:, permission_overrides: {}, client_ids: nil)
    @admin_user = admin_user
    @attrs = attrs
    @actor = actor
    @permission_overrides = permission_overrides
    @client_ids = client_ids
  end

  def call
    AdminUser.transaction do
      admin_user.assign_attributes(attrs)
      next admin_user if blocked_super_admin_assignment?
      next admin_user unless admin_user.save

      sync_permission_overrides
      sync_client_assignments
      admin_user
    end
  end

  private

  attr_reader :admin_user, :attrs, :actor, :permission_overrides, :client_ids

  # Same enforcement point as TeamMemberInviter — only a Super Admin may
  # assign the Super Admin role. The last-Super-Admin case (can't move
  # *away* from Super Admin) is a separate, model-level guard.
  def blocked_super_admin_assignment?
    return false unless admin_user.role_id == Role.super_admin.id
    return false if actor.role_id == Role.super_admin.id

    admin_user.errors.add(:role_id, "can only be assigned by a Super Admin")
    true
  end

  # A checkbox means "should this permission be effectively granted" — so a
  # checked box matching the role's own default needs no override row at
  # all; only the delta from the role default is ever stored.
  def sync_permission_overrides
    return if permission_overrides.blank?

    role_permission_keys = admin_user.role.permissions.pluck(:key).to_set
    permission_overrides.each do |key, value|
      next unless Permission::KEYS.include?(key)

      sync_one_permission_override(key, ActiveModel::Type::Boolean.new.cast(value), role_permission_keys)
    end
  end

  def sync_one_permission_override(key, checked, role_permission_keys)
    existing = admin_user.admin_user_permissions.find_by(permission_key: key)
    if checked == role_permission_keys.include?(key)
      existing&.destroy
    elsif existing
      existing.update!(granted: checked)
    else
      admin_user.admin_user_permissions.create!(permission_key: key, granted: checked)
    end
  end

  def sync_client_assignments
    return if client_ids.nil?

    admin_user.admin_user_client_assignments.destroy_all
    client_ids.reject(&:blank?).each { |id| admin_user.admin_user_client_assignments.create!(client_id: id) }
  end
end
