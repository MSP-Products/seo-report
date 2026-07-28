# frozen_string_literal: true

class CreateGbpPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :gbp_photos do |t|
      t.string :report_id, limit: 36, null: false
      t.string :image_url
      t.string :caption
    end

    add_foreign_key :gbp_photos, :monthly_reports, column: :report_id
  end
end
