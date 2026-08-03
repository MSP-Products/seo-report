class AddGenerationStartedAtToMonthlyReports < ActiveRecord::Migration[8.1]
  def change
    add_column :monthly_reports, :generation_started_at, :datetime
  end
end
