class CreateServices < ActiveRecord::Migration[8.1]
  # Scoped to this migration deliberately, rather than referencing the real
  # Service model — migrations should stay stable against future model
  # changes.
  class Service < ActiveRecord::Base
    self.primary_key = "key"
  end

  SERVICE_KEYS = %w[semrush yext google_analytics ghl hubspot].freeze

  def change
    create_table :services, id: false do |t|
      t.string :key, primary_key: true
      t.timestamps
    end

    # Reference data, not business data: the FK constraints below can't be
    # added until these rows exist, so — unlike ordinary data — this is
    # seeded in the migration itself rather than db/seeds.rb (see
    # CONVENTIONS.md §3's carve-out for schema-adjacent lookup tables).
    reversible do |dir|
      dir.up { SERVICE_KEYS.each { |key| Service.create!(key: key) } }
    end

    add_foreign_key :agency_connections, :services, column: :service, primary_key: :key
    add_foreign_key :client_service_links, :services, column: :service, primary_key: :key
  end
end
