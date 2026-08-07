class AddStatusAndErrorToServiceSyncLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :service_sync_logs, :status, :string
    add_column :service_sync_logs, :error_message, :text
  end
end
