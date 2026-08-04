class AddDurationSecondsToReportGenerationLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :report_generation_logs, :duration_seconds, :integer
  end
end
