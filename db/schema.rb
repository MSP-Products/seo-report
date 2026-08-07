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

  create_table "admin_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "password_digest"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

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
  add_foreign_key "send_logs", "monthly_reports"
  add_foreign_key "service_sync_logs", "clients"
  add_foreign_key "sitemap_pages", "clients"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
