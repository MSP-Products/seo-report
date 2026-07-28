# frozen_string_literal: true

class CreateGbpReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :gbp_reviews do |t|
      t.string :report_id, limit: 36, null: false
      t.string :external_id
      t.string :author_name
      t.date :posted_at
      t.text :body
      t.integer :rating
      t.string :sentiment
      t.boolean :needs_action, default: false
      t.text :owner_reply_text
      t.datetime :owner_replied_at
    end

    add_foreign_key :gbp_reviews, :monthly_reports, column: :report_id
    add_index :gbp_reviews, [:report_id, :external_id], unique: true
  end
end
