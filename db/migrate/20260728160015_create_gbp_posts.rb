# frozen_string_literal: true

class CreateGbpPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :gbp_posts do |t|
      t.string :report_id, limit: 36, null: false
      t.string :title
      t.date :published_at
      t.text :description
    end

    add_foreign_key :gbp_posts, :monthly_reports, column: :report_id
  end
end
