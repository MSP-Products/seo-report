# frozen_string_literal: true

# For tables whose id column defaults to MySQL's UUID() function
# (db/schema.rb: `id: { type: :string, limit: 36, default: -> { "(uuid())" } }`).
# The mysql2 adapter has no way to read back a function-generated default after
# INSERT, so without this the in-memory id stays blank/wrong after #create —
# breaking foreign keys on any association built off it in the same process
# (e.g. `client.monthly_reports.create!`). Generating the id in Ruby beforehand
# sidesteps that entirely; the DB-side default is just a fallback for inserts
# that bypass Rails.
module HasUuidPrimaryKey
  extend ActiveSupport::Concern

  included do
    before_create { self.id ||= SecureRandom.uuid }
  end
end
