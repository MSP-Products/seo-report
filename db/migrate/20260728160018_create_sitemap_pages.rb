# frozen_string_literal: true

class CreateSitemapPages < ActiveRecord::Migration[8.1]
  def change
    create_table :sitemap_pages do |t|
      t.string :client_id, limit: 36, null: false
      t.string :url, null: false
      t.string :title
      t.text :meta_description
      t.datetime :first_seen_at
      t.datetime :last_seen_at
    end

    add_foreign_key :sitemap_pages, :clients
    add_index :sitemap_pages, [ :client_id, :url ], unique: true
  end
end
