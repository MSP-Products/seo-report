class AddSyncTrackingToClientServiceLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :client_service_links, :last_synced_at, :datetime
    add_column :client_service_links, :last_sync_error, :string
  end
end
