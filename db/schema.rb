# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_28_160021) do
  create_table "admin_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "agency_connections", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "credential_status"
    t.text "encrypted_credentials"
    t.datetime "expires_at"
    t.datetime "last_verified_at"
    t.string "service", null: false
    t.datetime "updated_at", null: false
    t.index ["service"], name: "index_agency_connections_on_service", unique: true
  end

  create_table "client_keywords", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "client_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.string "intent"
    t.string "keyword", null: false
    t.integer "keyword_difficulty"
    t.integer "serp_features"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "fk_rails_ff22c74841"
  end

  create_table "client_service_links", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "client_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.string "credential_status"
    t.string "external_id"
    t.datetime "last_verified_at"
    t.text "override_credentials"
    t.string "service", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "service"], name: "index_client_service_links_on_client_id_and_service", unique: true
  end

  create_table "clients", id: { type: :string, limit: 36, default: -> { "(uuid())" } }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "address"
    t.boolean "ai_seo_enrolled", default: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.datetime "last_page_scan_at"
    t.string "last_page_scan_status"
    t.string "logo_url"
    t.string "name", null: false
    t.date "onboarded_at"
    t.string "onboarding_status"
    t.string "page_scan_method"
    t.string "phone"
    t.string "sitemap_url"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["discarded_at"], name: "index_clients_on_discarded_at"
  end

  create_table "gbp_photos", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "caption"
    t.string "image_url"
    t.string "report_id", limit: 36, null: false
    t.index ["report_id"], name: "fk_rails_b1aa7ec04f"
  end

  create_table "gbp_posts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "description"
    t.date "published_at"
    t.string "report_id", limit: 36, null: false
    t.string "title"
    t.index ["report_id"], name: "fk_rails_601bb308d9"
  end

  create_table "gbp_reviews", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "author_name"
    t.text "body"
    t.string "external_id"
    t.boolean "needs_action", default: false
    t.datetime "owner_replied_at"
    t.text "owner_reply_text"
    t.date "posted_at"
    t.integer "rating"
    t.string "report_id", limit: 36, null: false
    t.string "sentiment"
    t.index ["report_id", "external_id"], name: "index_gbp_reviews_on_report_id_and_external_id", unique: true
  end

  create_table "monthly_reports", id: { type: :string, limit: 36, default: -> { "(uuid())" } }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "access_token", null: false
    t.string "client_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.datetime "emailed_at"
    t.datetime "generated_at"
    t.boolean "is_first_report", default: false
    t.date "report_month", null: false
    t.datetime "updated_at", null: false
    t.index ["access_token"], name: "index_monthly_reports_on_access_token", unique: true
    t.index ["client_id", "report_month"], name: "index_monthly_reports_on_client_id_and_report_month", unique: true
  end

  create_table "report_ai_platform_scores", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "platform", null: false
    t.bigint "report_ai_visibility_id", null: false
    t.integer "score"
    t.index ["report_ai_visibility_id"], name: "index_report_ai_platform_scores_on_report_ai_visibility_id"
  end

  create_table "report_ai_visibilities", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "ai_rank"
    t.integer "citation_listings_pct"
    t.integer "citation_own_site_pct"
    t.integer "citation_reputation_pct"
    t.integer "citation_third_party_pct"
    t.integer "google_rank"
    t.integer "overall_score"
    t.integer "previous_score"
    t.string "report_id", limit: 36, null: false
    t.integer "sentiment_negative_pct"
    t.integer "sentiment_neutral_pct"
    t.integer "sentiment_positive_pct"
    t.index ["report_id"], name: "index_report_ai_visibilities_on_report_id", unique: true
  end

  create_table "report_citations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "driving_directions_count"
    t.integer "previous_engagements"
    t.integer "previous_impressions"
    t.string "report_id", limit: 36, null: false
    t.integer "total_engagements"
    t.integer "total_impressions"
    t.integer "website_clicks_count"
    t.index ["report_id"], name: "index_report_citations_on_report_id", unique: true
  end

  create_table "report_gbp_summaries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.decimal "average_rating", precision: 3, scale: 2
    t.boolean "needs_photos", default: false
    t.integer "new_negative_reviews"
    t.integer "new_positive_reviews"
    t.string "report_id", limit: 36, null: false
    t.integer "total_reviews"
    t.index ["report_id"], name: "index_report_gbp_summaries_on_report_id", unique: true
  end

  create_table "report_generation_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "attempted_at", null: false
    t.text "error_log"
    t.string "error_summary"
    t.string "monthly_report_id", limit: 36, null: false
    t.string "status", null: false
    t.index ["monthly_report_id", "attempted_at"], name: "idx_report_gen_logs_on_report_and_attempted"
  end

  create_table "report_highlights", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "ai_seo_summary_text"
    t.datetime "generated_at"
    t.string "model_used"
    t.string "report_id", limit: 36, null: false
    t.text "summary_text"
    t.index ["report_id"], name: "index_report_highlights_on_report_id", unique: true
  end

  create_table "report_keyword_rankings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.decimal "growth", precision: 10, scale: 2
    t.bigint "keyword_id", null: false
    t.integer "position"
    t.decimal "potential_traffic", precision: 10, scale: 2
    t.integer "previous_position"
    t.string "report_id", limit: 36, null: false
    t.index ["keyword_id"], name: "index_report_keyword_rankings_on_keyword_id"
    t.index ["report_id", "keyword_id"], name: "index_report_keyword_rankings_on_report_id_and_keyword_id", unique: true
  end

  create_table "report_pages_published", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "description"
    t.string "report_id", limit: 36, null: false
    t.bigint "sitemap_page_id", null: false
    t.string "title"
    t.string "url"
    t.index ["report_id"], name: "fk_rails_14c31e0e5c"
    t.index ["sitemap_page_id"], name: "index_report_pages_published_on_sitemap_page_id"
  end

  create_table "report_traffics", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "appointments_booked"
    t.integer "direct_visits"
    t.decimal "estimated_revenue", precision: 12, scale: 2
    t.string "ghl_data_status"
    t.integer "organic_visits"
    t.decimal "pages_per_visit", precision: 8, scale: 2
    t.integer "paid_visits"
    t.integer "previous_appointments_booked"
    t.integer "previous_direct_visits"
    t.decimal "previous_estimated_revenue", precision: 12, scale: 2
    t.integer "previous_organic_visits"
    t.integer "previous_paid_visits"
    t.integer "previous_referral_visits"
    t.integer "previous_total_visits"
    t.integer "referral_visits"
    t.string "report_id", limit: 36, null: false
    t.integer "total_visits"
    t.integer "unique_visitors"
    t.index ["report_id"], name: "index_report_traffics_on_report_id", unique: true
  end

  create_table "send_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "attempted_at", null: false
    t.text "error_message"
    t.string "monthly_report_id", limit: 36, null: false
    t.string "status", null: false
    t.index ["monthly_report_id"], name: "fk_rails_7b7fc24721"
  end

  create_table "sitemap_pages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "client_id", limit: 36, null: false
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.text "meta_description"
    t.string "title"
    t.string "url", null: false
    t.index ["client_id", "url"], name: "index_sitemap_pages_on_client_id_and_url", unique: true
  end

  add_foreign_key "client_keywords", "clients"
  add_foreign_key "client_service_links", "clients"
  add_foreign_key "gbp_photos", "monthly_reports", column: "report_id"
  add_foreign_key "gbp_posts", "monthly_reports", column: "report_id"
  add_foreign_key "gbp_reviews", "monthly_reports", column: "report_id"
  add_foreign_key "monthly_reports", "clients"
  add_foreign_key "report_ai_platform_scores", "report_ai_visibilities"
  add_foreign_key "report_ai_visibilities", "monthly_reports", column: "report_id"
  add_foreign_key "report_citations", "monthly_reports", column: "report_id"
  add_foreign_key "report_gbp_summaries", "monthly_reports", column: "report_id"
  add_foreign_key "report_generation_logs", "monthly_reports"
  add_foreign_key "report_highlights", "monthly_reports", column: "report_id"
  add_foreign_key "report_keyword_rankings", "client_keywords", column: "keyword_id"
  add_foreign_key "report_keyword_rankings", "monthly_reports", column: "report_id"
  add_foreign_key "report_pages_published", "monthly_reports", column: "report_id"
  add_foreign_key "report_pages_published", "sitemap_pages"
  add_foreign_key "report_traffics", "monthly_reports", column: "report_id"
  add_foreign_key "send_logs", "monthly_reports"
  add_foreign_key "sitemap_pages", "clients"
end
