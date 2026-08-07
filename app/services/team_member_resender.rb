# frozen_string_literal: true

# Regenerates a password for a team member who was invited but has never
# logged in, and hands it back once the same way TeamMemberInviter does.
# Refuses once someone has actually logged in — at that point a password
# reset is a different, not-yet-built concern, not a re-invite.
class TeamMemberResender
  def initialize(admin_user:)
    @admin_user = admin_user
  end

  def call
    return blocked_already_active if admin_user.last_active_at.present?

    password = SecureRandom.alphanumeric(16)
    admin_user.password = password
    admin_user.generated_password = password
    admin_user.save!
    CredentialDelivery.new(admin_user: admin_user, password: password).call
    admin_user
  end

  private

  attr_reader :admin_user

  def blocked_already_active
    admin_user.errors.add(:base, "#{admin_user.display_name} has already logged in — resend is only for members who haven't yet.")
    admin_user
  end
end
