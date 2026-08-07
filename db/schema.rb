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

ActiveRecord::Schema[8.1].define(version: 2026_08_07_091014) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admin_user_client_assignments", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.string "client_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id", "client_id"], name: "idx_admin_user_client_assignments_unique", unique: true
  end

  create_table "admin_user_permissions", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.datetime "created_at", null: false
    t.boolean "granted", null: false
    t.string "permission_key", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id", "permission_key"], name: "idx_admin_user_permissions_unique", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "email", null: false
    t.string "first_name"
    t.datetime "last_active_at"
    t.string "last_name"
    t.string "password_digest"
    t.string "role"
    t.bigint "role_id"
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_admin_users_on_discarded_at"
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["role_id"], name: "index_admin_users_on_role_id"
  end

  create_table "agency_connections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "credential_status"
    t.text "encrypted_credentials"
    t.datetime "expires_at"
    t.datetime "last_verified_at"
    t.string "service", null: false
    t.datetime "updated_at", null: false
    t.index ["service"], name: "index_agency_connections_on_service", unique: true
  end

  create_table "client_keywords", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "client_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.string "intent"
    t.string "keyword", null: false
    t.integer "keyword_difficulty"
    t.integer "serp_features"
    t.datetime "updated_at", null: false
    t.index ["client_id", "keyword"], name: "index_client_keywords_on_client_id_and_keyword", unique: true
  end

  create_table "client_service_links", force: :cascade do |t|
    t.string "client_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.string "credential_status"
    t.string "external_id"
    t.string "last_sync_error"
    t.datetime "last_synced_at"
    t.datetime "last_verified_at"
    t.text "override_credentials"
    t.string "service", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "service"], name: "index_client_service_links_on_client_id_and_service", unique: true
  end

  create_table "clients", id: { type: :string, limit: 36, default: -> { "gen_random_uuid()" } }, force: :cascade do |t|
    t.string "address"
    t.boolean "ai_seo_enrolled", default: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.datetime "last_page_scan_at"
    t.string "last_page_scan_status"
    t.string "logo_url"
    t.string "name", null: false
    t.date "onboarded_at"
    t.string "onboarding_status", default: "pending"
    t.string "page_scan_method"
    t.string "phone"
    t.string "sitemap_url"
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["discarded_at"], name: "index_clients_on_discarded_at"
  end

  create_table "gbp_photos", force: :cascade do |t|
    t.string "caption"
    t.string "image_url"
    t.string "report_id", limit: 36, null: false
  end

  create_table "gbp_posts", force: :cascade do |t|
    t.text "description"
    t.date "published_at"
    t.string "report_id", limit: 36, null: false
    t.string "title"
  end

  create_table "gbp_reviews", force: :cascade do |t|
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

  create_table "monthly_reports", id: { type: :string, limit: 36, default: -> { "gen_random_uuid()" } }, force: :cascade do |t|
    t.string "access_token", null: false
    t.integer "attempt_count", default: 0, null: false
    t.string "client_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.datetime "emailed_at"
    t.datetime "generated_at"
    t.datetime "generation_started_at"
    t.string "generation_status", default: "queued", null: false
    t.boolean "is_first_report", default: false
    t.date "report_month", null: false
    t.datetime "updated_at", null: false
    t.index ["access_token"], name: "index_monthly_reports_on_access_token", unique: true
    t.index ["client_id", "report_month"], name: "index_monthly_reports_on_client_id_and_report_month", unique: true
  end

  create_table "permissions", primary_key: "key", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "report_ai_platform_scores", force: :cascade do |t|
    t.string "platform", null: false
    t.bigint "report_ai_visibility_id", null: false
    t.integer "score"
    t.index ["report_ai_visibility_id"], name: "index_report_ai_platform_scores_on_report_ai_visibility_id"
  end

  create_table "report_ai_visibilities", force: :cascade do |t|
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

  create_table "report_citations", force: :cascade do |t|
    t.integer "driving_directions_count"
    t.integer "previous_engagements"
    t.integer "previous_impressions"
    t.string "report_id", limit: 36, null: false
    t.integer "total_engagements"
    t.integer "total_impressions"
    t.integer "website_clicks_count"
    t.index ["report_id"], name: "index_report_citations_on_report_id", unique: true
  end

  create_table "report_gbp_summaries", force: :cascade do |t|
    t.decimal "average_rating", precision: 3, scale: 2
    t.boolean "needs_photos", default: false
    t.integer "new_negative_reviews"
    t.integer "new_positive_reviews"
    t.string "report_id", limit: 36, null: false
    t.integer "total_reviews"
    t.index ["report_id"], name: "index_report_gbp_summaries_on_report_id", unique: true
  end

  create_table "report_generation_logs", force: :cascade do |t|
    t.datetime "attempted_at", null: false
    t.text "error_log"
    t.string "error_summary"
    t.string "monthly_report_id", limit: 36, null: false
    t.string "status", null: false
    t.index ["monthly_report_id", "attempted_at"], name: "idx_report_gen_logs_on_report_and_attempted"
  end

  create_table "report_highlights", force: :cascade do |t|
    t.text "ai_seo_summary_text"
    t.datetime "generated_at"
    t.string "model_used"
    t.string "report_id", limit: 36, null: false
    t.text "summary_text"
    t.index ["report_id"], name: "index_report_highlights_on_report_id", unique: true
  end

  create_table "report_keyword_rankings", force: :cascade do |t|
    t.decimal "growth", precision: 10, scale: 2
    t.string "intent"
    t.integer "keyword_difficulty"
    t.bigint "keyword_id", null: false
    t.integer "position"
    t.decimal "potential_traffic", precision: 10, scale: 2
    t.integer "previous_position"
    t.string "report_id", limit: 36, null: false
    t.integer "serp_features"
    t.index ["keyword_id"], name: "index_report_keyword_rankings_on_keyword_id"
    t.index ["report_id", "keyword_id"], name: "index_report_keyword_rankings_on_report_id_and_keyword_id", unique: true
  end

  create_table "report_pages_published", force: :cascade do |t|
    t.text "description"
    t.string "report_id", limit: 36, null: false
    t.bigint "sitemap_page_id", null: false
    t.string "title"
    t.string "url"
    t.index ["sitemap_page_id"], name: "index_report_pages_published_on_sitemap_page_id"
  end

  create_table "report_traffics", force: :cascade do |t|
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

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "permission_key", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id", "permission_key"], name: "idx_role_permissions_unique", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "send_logs", force: :cascade do |t|
    t.datetime "attempted_at", null: false
    t.text "error_message"
    t.string "monthly_report_id", limit: 36, null: false
    t.string "status", null: false
  end

  create_table "service_sync_logs", force: :cascade do |t|
    t.string "client_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms", null: false
    t.text "error_message"
    t.string "service", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["service", "created_at"], name: "index_service_sync_logs_on_service_and_created_at"
  end

  create_table "services", primary_key: "key", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sitemap_pages", force: :cascade do |t|
    t.string "client_id", limit: 36, null: false
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.text "meta_description"
    t.string "title"
    t.string "url", null: false
    t.index ["client_id", "url"], name: "index_sitemap_pages_on_client_id_and_url", unique: true
  end

  add_foreign_key "admin_user_client_assignments", "admin_users"
  add_foreign_key "admin_user_client_assignments", "clients"
  add_foreign_key "admin_user_permissions", "admin_users"
  add_foreign_key "admin_user_permissions", "permissions", column: "permission_key", primary_key: "key"
  add_foreign_key "admin_users", "roles"
  add_foreign_key "agency_connections", "services", column: "service", primary_key: "key"
  add_foreign_key "client_keywords", "clients"
  add_foreign_key "client_service_links", "clients"
  add_foreign_key "client_service_links", "services", column: "service", primary_key: "key"
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
  add_foreign_key "role_permissions", "permissions", column: "permission_key", primary_key: "key"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "send_logs", "monthly_reports"
  add_foreign_key "service_sync_logs", "clients"
  add_foreign_key "sitemap_pages", "clients"
end
