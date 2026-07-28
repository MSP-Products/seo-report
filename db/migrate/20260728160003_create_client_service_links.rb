# frozen_string_literal: true

class CreateClientServiceLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :client_service_links do |t|
      t.string :client_id, limit: 36, null: false
      t.string :service, null: false
      t.string :external_id
      t.text :override_credentials
      t.string :credential_status
      t.datetime :last_verified_at

      t.timestamps
    end

    add_foreign_key :client_service_links, :clients
    add_index :client_service_links, [:client_id, :service], unique: true
  end
end
