# Recovery path for a dev/local GHL connection that has no OAuth redirect URI
# of its own registered with GHL (only production's stable Railway URL and,
# transiently, an ngrok tunnel are). The agency-level grant is the same GHL
# company regardless of which environment's database holds it, so a fresh
# access_token/refresh_token pair obtained anywhere (production, which always
# has a valid registered redirect URI) can be copied into another
# environment's AgencyConnection row directly — no redirect URI, no GHL
# Marketplace app version needed. See docs/features/integration-ghl.md.
#
# The printed JSON contains a live access_token/refresh_token — handle it like
# any other credential (don't paste it into a shared channel, log, or ticket).
namespace :ghl do
  desc "Print this environment's GHL agency connection as JSON, for ghl:import_connection"
  task print_connection: :environment do
    connection = AgencyConnection.find_by(service: "ghl")
    abort "No GHL AgencyConnection found in this environment." unless connection

    puts connection.credentials.merge("expires_at" => connection.expires_at.iso8601).to_json
  end

  desc "Import a GHL agency connection printed by ghl:print_connection: GHL_CONNECTION_JSON=... bin/rails ghl:import_connection"
  task import_connection: :environment do
    payload = JSON.parse(ENV.fetch("GHL_CONNECTION_JSON"))
    expires_at = Time.zone.parse(payload.delete("expires_at"))

    connection = AgencyConnection.find_or_initialize_by(service: "ghl")
    connection.update!(encrypted_credentials: payload.to_json, expires_at: expires_at,
      credential_status: "active", last_verified_at: Time.current)

    puts "Imported GHL connection — expires_at=#{expires_at}"
  end
end
