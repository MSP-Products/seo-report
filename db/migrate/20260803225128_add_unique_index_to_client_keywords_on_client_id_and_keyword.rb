class AddUniqueIndexToClientKeywordsOnClientIdAndKeyword < ActiveRecord::Migration[8.1]
  def change
    add_index :client_keywords, [ :client_id, :keyword ], unique: true
  end
end
