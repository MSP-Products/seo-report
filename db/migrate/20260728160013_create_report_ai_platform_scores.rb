# frozen_string_literal: true

class CreateReportAiPlatformScores < ActiveRecord::Migration[8.1]
  def change
    create_table :report_ai_platform_scores do |t|
      t.references :report_ai_visibility, type: :bigint, null: false, foreign_key: true
      t.string :platform, null: false
      t.integer :score
    end
  end
end
