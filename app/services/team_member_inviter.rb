# frozen_string_literal: true

# Creates a new AdminUser with an auto-generated password (no invite-email
# infrastructure exists yet — see CredentialDelivery) and hands the plaintext
# back once, via AdminUser#generated_password, for the controller to render.
class TeamMemberInviter
  def initialize(attrs:, actor:)
    @attrs = attrs
    @actor = actor
  end

  def call
    AdminUser.transaction do
      admin_user = build_admin_user
      next admin_user if blocked_super_admin_assignment?(admin_user)
      next admin_user unless admin_user.save

      CredentialDelivery.new(admin_user: admin_user, password: admin_user.generated_password).call
      admin_user
    end
  end

  private

  attr_reader :attrs, :actor

  def build_admin_user
    password = SecureRandom.alphanumeric(16)
    AdminUser.new(attrs).tap do |admin_user|
      admin_user.password = password
      admin_user.generated_password = password
    end
  end

  # Only a Super Admin may assign the Super Admin role — an Admin inviting or
  # editing someone into it is blocked here, the actual enforcement point;
  # AdminUser#assignable_roles only keeps the form's visible options honest.
  def blocked_super_admin_assignment?(admin_user)
    return false unless admin_user.role_id == Role.super_admin.id
    return false if actor.role_id == Role.super_admin.id

    admin_user.errors.add(:role_id, "can only be assigned by a Super Admin")
    true
  end
end
