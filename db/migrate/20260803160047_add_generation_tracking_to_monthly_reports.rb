class AddGenerationTrackingToMonthlyReports < ActiveRecord::Migration[8.1]
  def up
    add_column :monthly_reports, :generation_status, :string, null: false, default: "queued"
    add_column :monthly_reports, :attempt_count, :integer, null: false, default: 0

    # Backfill only — existing rows already carry the truth in generated_at,
    # this just brings the new column in line with it so "queued" means what
    # it says for every row going forward.
    execute <<~SQL
      UPDATE monthly_reports SET generation_status = 'ready' WHERE generated_at IS NOT NULL
    SQL
  end

  def down
    remove_column :monthly_reports, :attempt_count
    remove_column :monthly_reports, :generation_status
  end
end
