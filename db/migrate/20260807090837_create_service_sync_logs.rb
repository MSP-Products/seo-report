class CreateServiceSyncLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :service_sync_logs do |t|
      t.string :client_id, null: false
      t.string :service, null: false
      t.integer :duration_ms, null: false

      t.timestamps
    end

    add_foreign_key :service_sync_logs, :clients, column: :client_id
    add_index :service_sync_logs, [ :service, :created_at ]
  end
end
