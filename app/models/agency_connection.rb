# frozen_string_literal: true

class AgencyConnection < ApplicationRecord
  encrypts :encrypted_credentials

  # Enums
  enum :service, {
    semrush: "semrush",
    yext: "yext",
    google_analytics: "google_analytics",
    ghl: "ghl",
    hubspot: "hubspot"
  }, validate: true

  # prefix avoids "invalid?" clashing with ActiveRecord::Base#invalid? (validation state);
  # allow_nil since a connection has no status until first verified.
  enum :credential_status, {
    active: "active",
    expiring_soon: "expiring_soon",
    expired: "expired",
    invalid: "invalid"
  }, prefix: :credential, validate: { allow_nil: true }

  # Credentials are stored as a JSON blob (e.g. {"api_key" => "..."} or
  # {"access_token" => "...", "refresh_token" => "..."}) — shape varies per service.
  def credentials
    JSON.parse(encrypted_credentials.presence || "{}")
  end

  def configured?
    encrypted_credentials.present?
  end

  # Friendly per-service credential field(s) for the Connections form — so an
  # MSP admin fills in "Access Token"/"API Key", never raw JSON.
  # google_analytics has none: it's a stub with no live integration yet.
  CREDENTIAL_FIELDS = {
    "hubspot" => [ { key: "access_token", label: "Access Token" } ],
    "ghl" => [ { key: "access_token", label: "Access Token" } ],
    "yext" => [ { key: "api_key", label: "API Key" } ],
    "semrush" => [ { key: "api_key", label: "API Key" } ],
    "google_analytics" => []
  }.freeze

  # Display metadata for the Connections page (badge letter/full class, name).
  # badge_class is a complete Tailwind class string, not assembled from a color
  # name at render time — Tailwind's build only picks up classes it can find
  # as literal text in the source, so interpolating "bg-#{color}-500" in a
  # view would silently fail to generate the CSS.
  DISPLAY = {
    "hubspot" => { name: "HubSpot", letter: "H", badge_class: "bg-rose-500" },
    "ghl" => { name: "GoHighLevel", letter: "G", badge_class: "bg-violet-500" },
    "yext" => { name: "Yext", letter: "Y", badge_class: "bg-red-500" },
    "semrush" => { name: "SEMrush", letter: "S", badge_class: "bg-orange-500" },
    "google_analytics" => { name: "Google Analytics", letter: "G", badge_class: "bg-amber-500" }
  }.freeze

  def display_name
    DISPLAY.fetch(service)[:name]
  end

  def credential_fields
    CREDENTIAL_FIELDS.fetch(service)
  end

  def status_label
    return "Not available yet" if credential_fields.empty?
    return "Active" if credential_active?
    return "Expiring soon" if credential_expiring_soon?
    return "Expired" if credential_expired?
    return "Needs attention" if credential_invalid?

    configured? ? "Unverified" : "Not configured"
  end

  def status_dot_class
    return "bg-emerald-500" if credential_active?
    return "bg-amber-500" if credential_expiring_soon?
    return "bg-red-500" if credential_expired? || credential_invalid?

    "bg-slate-300"
  end
end
