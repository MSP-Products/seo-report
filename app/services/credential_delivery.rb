# frozen_string_literal: true

# The single, swappable seam for "how a new AdminUser learns their password."
# No mailer exists yet (production.rb's mail host is still the example.com
# placeholder), and whether it's ever a real ActionMailer send or a
# HubSpot-triggered email is an explicit decision still pending externally.
# Today this does nothing beyond making the plaintext available via
# AdminUser#generated_password for the controller to render once. Swap
# #call's body later; nothing that calls this class needs to change.
class CredentialDelivery
  def initialize(admin_user:, password:)
    @admin_user = admin_user
    @password = password
  end

  def call
    true
  end
end
