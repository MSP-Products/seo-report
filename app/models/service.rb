# frozen_string_literal: true

# The single source of truth for valid service keys ("yext", "semrush", ...) —
# backs the FK constraints on agency_connections.service and
# client_service_links.service, replacing what used to be the same hardcoded
# list duplicated across two enum declarations.
#
# Display metadata (name, badge color) and credential field definitions stay
# in AgencyConnection::DISPLAY/CREDENTIAL_FIELDS, not here — Tailwind's build
# only compiles class names it can find as literal text in Ruby source, so a
# DB-driven badge_class would never get its CSS generated (see
# CONVENTIONS.md's views section).
class Service < ApplicationRecord
  self.primary_key = "key"

  # The migration that creates this table seeds these same keys directly
  # (reference data the FK constraints depend on existing) — this constant is
  # for other Ruby code that needs the list, e.g. the test suite bootstrapping
  # a schema-loaded (not fully migrated) test database.
  KEYS = %w[semrush yext google_analytics ghl hubspot].freeze

  validates :key, presence: true
end
