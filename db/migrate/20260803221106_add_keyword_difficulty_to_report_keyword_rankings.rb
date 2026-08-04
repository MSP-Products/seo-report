class AddKeywordDifficultyToReportKeywordRankings < ActiveRecord::Migration[8.1]
  def change
    add_column :report_keyword_rankings, :keyword_difficulty, :integer
  end
end
