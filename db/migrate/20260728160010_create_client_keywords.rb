# frozen_string_literal: true

class CreateClientKeywords < ActiveRecord::Migration[8.1]
  def change
    create_table :client_keywords do |t|
      t.string :client_id, limit: 36, null: false
      t.string :keyword, null: false
      t.string :intent
      t.integer :serp_features
      t.integer :keyword_difficulty
      t.boolean :active, default: true

      t.timestamps
    end

    add_foreign_key :client_keywords, :clients
  end
end
