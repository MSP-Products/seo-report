# frozen_string_literal: true

class CreateAgencyConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :agency_connections do |t|
      t.string :service, null: false
      t.text :encrypted_credentials
      t.string :credential_status
      t.datetime :expires_at
      t.datetime :last_verified_at

      t.timestamps
    end

    add_index :agency_connections, :service, unique: true
  end
end
