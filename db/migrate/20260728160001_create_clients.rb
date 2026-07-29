# frozen_string_literal: true

class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients, id: false do |t|
      t.string :id, limit: 36, primary_key: true, default: -> { "(UUID())" }
      t.string :name, null: false
      t.string :address
      t.string :phone
      t.string :logo_url
      t.string :website_url
      t.string :sitemap_url
      t.string :onboarding_status
      t.date :onboarded_at
      t.boolean :ai_seo_enrolled, default: false
      t.string :page_scan_method
      t.datetime :last_page_scan_at
      t.string :last_page_scan_status

      t.timestamps
    end
  end
end
