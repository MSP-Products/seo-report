class AddIntentAndSerpFeaturesToReportKeywordRankings < ActiveRecord::Migration[8.1]
  def change
    add_column :report_keyword_rankings, :intent, :string
    add_column :report_keyword_rankings, :serp_features, :integer
  end
end
