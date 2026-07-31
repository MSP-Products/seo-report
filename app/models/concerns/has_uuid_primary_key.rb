# frozen_string_literal: true

# For tables whose id column defaults to a DB-generated UUID
# (db/schema.rb: `id: { type: :string, limit: 36, default: -> { "gen_random_uuid()" } }`).
# Postgres's `pg` adapter returns generated defaults via `INSERT ... RETURNING`,
# so this isn't strictly required the way it was under MySQL's mysql2 adapter
# (which couldn't read back a function-generated default after INSERT at all) —
# kept anyway as a portable, explicit guarantee that id is always set before
# the first save, independent of adapter behavior. The DB-side default remains
# a fallback for inserts that bypass Rails entirely.
module HasUuidPrimaryKey
  extend ActiveSupport::Concern

  included do
    before_create { self.id ||= SecureRandom.uuid }
  end
end
