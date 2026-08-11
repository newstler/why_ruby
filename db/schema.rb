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

ActiveRecord::Schema[8.2].define(version: 2026_04_10_161960) do
  create_table "_litestream_lock", id: false, force: :cascade do |t|
    t.integer "id"
  end

  create_table "_litestream_seq", id: :integer, default: nil, force: :cascade do |t|
    t.integer "seq"
  end

  create_table "active_storage_attachments", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "articles", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "team_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["team_id"], name: "index_articles_on_team_id"
    t.index ["user_id"], name: "index_articles_on_user_id"
  end

  create_table "categories", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_success_story", default: false, null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["is_success_story"], name: "index_categories_on_is_success_story", unique: true, where: "is_success_story = true"
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["position"], name: "index_categories_on_position", unique: true
    t.index ["slug"], name: "index_categories_on_slug"
  end

  create_table "chats", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "messages_count", default: 0, null: false
    t.string "model_id"
    t.string "purpose", default: "conversation"
    t.string "team_id"
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["model_id"], name: "index_chats_on_model_id"
    t.index ["purpose"], name: "index_chats_on_purpose"
    t.index ["team_id"], name: "index_chats_on_team_id"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "comments", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "post_id", null: false
    t.boolean "published", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["created_at"], name: "index_comments_on_created_at"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["published"], name: "index_comments_on_published"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.string "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "languages", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.string "native_name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
  end

  create_table "memberships", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "invited_by_id"
    t.string "role", default: "member", null: false
    t.string "team_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["invited_by_id"], name: "index_memberships_on_invited_by_id"
    t.index ["team_id"], name: "index_memberships_on_team_id"
    t.index ["user_id", "team_id"], name: "index_memberships_on_user_id_and_team_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.string "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.decimal "cost", precision: 10, scale: 6, default: "0.0"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.string "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.string "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "mobility_string_translations", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "locale", null: false
    t.string "translatable_id", null: false
    t.string "translatable_type", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_string_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_string_translations_on_keys", unique: true
    t.index ["translatable_type", "key", "value", "locale"], name: "index_mobility_string_translations_on_query_keys"
  end

  create_table "mobility_text_translations", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "locale", null: false
    t.string "translatable_id", null: false
    t.string "translatable_type", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["translatable_id", "translatable_type", "key"], name: "index_mobility_text_translations_on_translatable_attribute"
    t.index ["translatable_id", "translatable_type", "locale", "key"], name: "index_mobility_text_translations_on_keys", unique: true
  end

  create_table "models", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "chats_count", default: 0, null: false
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.json "metadata", default: {}
    t.json "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.json "pricing", default: {}
    t.string "provider", null: false
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["family"], name: "index_models_on_family"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "posts", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "category_id", null: false
    t.integer "comments_count", default: 0, null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.json "image_variants"
    t.text "logo_svg"
    t.boolean "needs_admin_review", default: false, null: false
    t.integer "pin_position"
    t.string "post_type", default: "article", null: false
    t.boolean "published", default: false, null: false
    t.integer "reports_count", default: 0, null: false
    t.string "slug"
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "user_id", null: false
    t.index ["category_id"], name: "index_posts_on_category_id"
    t.index ["created_at"], name: "index_posts_on_created_at"
    t.index ["needs_admin_review"], name: "index_posts_on_needs_admin_review"
    t.index ["pin_position"], name: "index_posts_on_pin_position", unique: true, where: "pin_position IS NOT NULL"
    t.index ["post_type"], name: "index_posts_on_post_type"
    t.index ["published"], name: "index_posts_on_published"
    t.index ["slug"], name: "index_posts_on_slug"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "posts_tags", id: false, force: :cascade do |t|
    t.string "post_id", null: false
    t.string "tag_id", null: false
    t.index ["post_id", "tag_id"], name: "index_posts_tags_on_post_id_and_tag_id", unique: true
    t.index ["post_id"], name: "index_posts_tags_on_post_id"
    t.index ["tag_id", "post_id"], name: "index_posts_tags_on_tag_id_and_post_id"
    t.index ["tag_id"], name: "index_posts_tags_on_tag_id"
  end

  create_table "projects", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "forks_count", default: 0, null: false
    t.string "github_url", null: false
    t.boolean "hidden", default: false, null: false
    t.string "name", null: false
    t.datetime "pushed_at"
    t.integer "size", default: 0, null: false
    t.integer "stars", default: 0, null: false
    t.json "topics", default: []
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["archived"], name: "index_projects_on_archived"
    t.index ["stars"], name: "index_projects_on_stars"
    t.index ["user_id", "github_url"], name: "index_projects_on_user_id_and_github_url", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "provider_credentials", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.string "value"
    t.index ["provider", "key"], name: "index_provider_credentials_on_provider_and_key", unique: true
  end

  create_table "rails_error_dashboard_applications", force: :cascade do |t|
    t.datetime "created_at"
    t.text "description"
    t.string "name", limit: 255, null: false
    t.datetime "updated_at"
    t.index ["name"], name: "index_rails_error_dashboard_applications_on_name", unique: true
  end

  create_table "rails_error_dashboard_cascade_patterns", force: :cascade do |t|
    t.float "avg_delay_seconds"
    t.float "cascade_probability"
    t.bigint "child_error_id", null: false
    t.datetime "created_at", null: false
    t.integer "frequency", default: 1, null: false
    t.datetime "last_detected_at"
    t.bigint "parent_error_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cascade_probability"], name: "index_cascade_patterns_on_probability"
    t.index ["child_error_id"], name: "index_cascade_patterns_on_child"
    t.index ["parent_error_id", "child_error_id"], name: "index_cascade_patterns_on_parent_and_child", unique: true
    t.index ["parent_error_id"], name: "index_cascade_patterns_on_parent"
  end

  create_table "rails_error_dashboard_diagnostic_dumps", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "captured_at", null: false
    t.datetime "created_at", null: false
    t.text "dump_data", null: false
    t.string "note"
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_rails_error_dashboard_diagnostic_dumps_on_application_id"
    t.index ["captured_at"], name: "index_diagnostic_dumps_on_captured_at"
  end

  create_table "rails_error_dashboard_error_baselines", force: :cascade do |t|
    t.string "baseline_type", null: false
    t.integer "count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "error_type", null: false
    t.float "mean"
    t.float "percentile_95"
    t.float "percentile_99"
    t.datetime "period_end", null: false
    t.datetime "period_start", null: false
    t.string "platform", null: false
    t.integer "sample_size", default: 0, null: false
    t.float "std_dev"
    t.datetime "updated_at", null: false
    t.index ["error_type", "platform", "baseline_type", "period_start"], name: "index_error_baselines_on_type_platform_baseline_period"
    t.index ["error_type", "platform"], name: "index_error_baselines_on_error_type_and_platform"
    t.index ["period_end"], name: "index_error_baselines_on_period_end"
  end

  create_table "rails_error_dashboard_error_comments", force: :cascade do |t|
    t.string "author_name", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "error_log_id", null: false
    t.datetime "updated_at", null: false
    t.index ["error_log_id", "created_at"], name: "index_error_comments_on_error_and_time"
    t.index ["error_log_id"], name: "index_rails_error_dashboard_error_comments_on_error_log_id"
  end

  create_table "rails_error_dashboard_error_logs", force: :cascade do |t|
    t.string "action_name"
    t.string "app_version"
    t.bigint "application_id", null: false
    t.datetime "assigned_at"
    t.string "assigned_to"
    t.text "backtrace"
    t.string "backtrace_signature"
    t.text "breadcrumbs"
    t.string "content_type", limit: 100
    t.string "controller_name"
    t.datetime "created_at", null: false
    t.text "environment_info"
    t.string "error_hash"
    t.string "error_type", null: false
    t.text "exception_cause"
    t.integer "external_issue_number"
    t.string "external_issue_provider", limit: 20
    t.string "external_issue_url"
    t.datetime "first_seen_at"
    t.string "git_sha"
    t.string "hostname", limit: 255
    t.string "http_method", limit: 10
    t.text "instance_variables"
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.text "local_variables"
    t.text "message", null: false
    t.boolean "muted", default: false, null: false
    t.datetime "muted_at"
    t.string "muted_by"
    t.string "muted_reason"
    t.datetime "occurred_at", null: false
    t.integer "occurrence_count", default: 1, null: false
    t.string "platform"
    t.integer "priority_level", default: 0
    t.integer "priority_score"
    t.datetime "reopened_at"
    t.integer "request_duration_ms"
    t.text "request_params"
    t.text "request_url"
    t.text "resolution_comment"
    t.string "resolution_reference"
    t.boolean "resolved", default: false, null: false
    t.datetime "resolved_at"
    t.string "resolved_by_name"
    t.float "similarity_score"
    t.datetime "snoozed_until"
    t.string "status", default: "new"
    t.text "system_health"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.integer "user_id"
    t.index ["app_version", "resolved", "occurred_at"], name: "index_error_logs_on_version_resolution_time"
    t.index ["app_version"], name: "index_rails_error_dashboard_error_logs_on_app_version"
    t.index ["application_id", "occurred_at"], name: "index_error_logs_on_app_occurred"
    t.index ["application_id", "resolved"], name: "index_error_logs_on_app_resolved"
    t.index ["application_id"], name: "index_rails_error_dashboard_error_logs_on_application_id"
    t.index ["assigned_to", "status", "occurred_at"], name: "index_error_logs_on_assignment_workflow"
    t.index ["backtrace_signature"], name: "index_rails_error_dashboard_error_logs_on_backtrace_signature"
    t.index ["controller_name", "action_name", "error_hash"], name: "index_error_logs_on_controller_action_hash"
    t.index ["error_hash", "resolved", "occurred_at"], name: "index_error_logs_on_hash_resolved_occurred"
    t.index ["error_hash"], name: "index_rails_error_dashboard_error_logs_on_error_hash"
    t.index ["error_type", "occurred_at"], name: "index_error_logs_on_error_type_and_occurred_at"
    t.index ["error_type"], name: "index_rails_error_dashboard_error_logs_on_error_type"
    t.index ["first_seen_at"], name: "index_rails_error_dashboard_error_logs_on_first_seen_at"
    t.index ["git_sha"], name: "index_rails_error_dashboard_error_logs_on_git_sha"
    t.index ["last_seen_at"], name: "index_rails_error_dashboard_error_logs_on_last_seen_at"
    t.index ["muted"], name: "index_rails_error_dashboard_error_logs_on_muted"
    t.index ["occurred_at"], name: "index_rails_error_dashboard_error_logs_on_occurred_at"
    t.index ["occurrence_count"], name: "index_rails_error_dashboard_error_logs_on_occurrence_count"
    t.index ["platform", "occurred_at"], name: "index_error_logs_on_platform_and_occurred_at"
    t.index ["platform", "status", "occurred_at"], name: "index_error_logs_on_platform_status_time"
    t.index ["platform"], name: "index_rails_error_dashboard_error_logs_on_platform"
    t.index ["priority_level", "resolved", "occurred_at"], name: "index_error_logs_on_priority_resolution"
    t.index ["priority_score"], name: "index_rails_error_dashboard_error_logs_on_priority_score"
    t.index ["resolved", "occurred_at"], name: "index_error_logs_on_resolved_and_occurred_at"
    t.index ["resolved"], name: "index_rails_error_dashboard_error_logs_on_resolved"
    t.index ["similarity_score"], name: "index_rails_error_dashboard_error_logs_on_similarity_score"
    t.index ["user_id"], name: "index_rails_error_dashboard_error_logs_on_user_id"
  end

  create_table "rails_error_dashboard_error_occurrences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "error_log_id", null: false
    t.datetime "occurred_at", null: false
    t.string "request_id"
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["error_log_id"], name: "index_error_occurrences_on_error_log"
    t.index ["occurred_at", "error_log_id"], name: "index_error_occurrences_on_time_and_error"
    t.index ["request_id"], name: "index_error_occurrences_on_request"
    t.index ["user_id"], name: "index_error_occurrences_on_user"
  end

  create_table "rails_error_dashboard_swallowed_exceptions", force: :cascade do |t|
    t.bigint "application_id"
    t.datetime "created_at", null: false
    t.string "exception_class", limit: 250, null: false
    t.datetime "last_seen_at"
    t.datetime "period_hour", null: false
    t.integer "raise_count", default: 0, null: false
    t.string "raise_location", limit: 250, null: false
    t.integer "rescue_count", default: 0, null: false
    t.string "rescue_location", limit: 250
    t.datetime "updated_at", null: false
    t.index ["application_id", "period_hour"], name: "index_swallowed_exceptions_on_app_and_hour"
    t.index ["exception_class", "period_hour"], name: "index_swallowed_exceptions_on_class_and_hour"
    t.index ["exception_class", "raise_location", "rescue_location", "period_hour", "application_id"], name: "index_swallowed_exceptions_upsert_key", unique: true
    t.index ["period_hour"], name: "index_swallowed_exceptions_on_period_hour"
  end

  create_table "reports", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "post_id", null: false
    t.integer "reason", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["post_id"], name: "index_reports_on_post_id"
    t.index ["user_id", "post_id"], name: "index_reports_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "settings", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "default_ai_model"
    t.string "github_api_token"
    t.string "github_rubycommunity_client_id"
    t.string "github_rubycommunity_client_secret"
    t.string "github_whyruby_client_id"
    t.string "github_whyruby_client_secret"
    t.string "litestream_replica_access_key"
    t.string "litestream_replica_bucket"
    t.string "litestream_replica_key_id"
    t.string "mail_from"
    t.boolean "public_chats", default: true, null: false
    t.string "smtp_address"
    t.string "smtp_password"
    t.string "smtp_username"
    t.string "stripe_publishable_key"
    t.string "stripe_secret_key"
    t.string "stripe_webhook_secret"
    t.string "summary_model"
    t.string "testimonial_model"
    t.string "translation_model"
    t.integer "trial_days", default: 30
    t.datetime "updated_at", null: false
    t.string "validation_model"
  end

  create_table "star_snapshots", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "project_id", null: false
    t.date "recorded_on", null: false
    t.integer "stars", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "recorded_on"], name: "index_star_snapshots_on_project_id_and_recorded_on", unique: true
    t.index ["recorded_on"], name: "index_star_snapshots_on_recorded_on"
  end

  create_table "tags", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug"
  end

  create_table "team_languages", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "language_id", null: false
    t.string "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id"], name: "index_team_languages_on_language_id"
    t.index ["team_id", "language_id"], name: "index_team_languages_on_team_id_and_language_id", unique: true
    t.index ["team_id"], name: "index_team_languages_on_team_id"
  end

  create_table "teams", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "api_key", null: false
    t.boolean "cancel_at_period_end", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "current_period_ends_at"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "subscription_status"
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "index_teams_on_api_key", unique: true
    t.index ["slug"], name: "index_teams_on_slug", unique: true
    t.index ["stripe_customer_id"], name: "index_teams_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_teams_on_stripe_subscription_id", unique: true
  end

  create_table "testimonials", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.integer "ai_attempts", default: 0
    t.text "ai_feedback"
    t.text "body_text"
    t.datetime "created_at", null: false
    t.string "heading"
    t.integer "position"
    t.boolean "published", default: false
    t.text "quote"
    t.string "reject_reason"
    t.string "subheading"
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["heading"], name: "index_testimonials_on_heading"
    t.index ["position"], name: "index_testimonials_on_position"
    t.index ["published"], name: "index_testimonials_on_published"
    t.index ["user_id"], name: "index_testimonials_on_user_id", unique: true
  end

  create_table "tool_calls", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.string "message_id", null: false
    t.string "name", null: false
    t.string "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "users", id: :string, default: -> { "uuid7()" }, force: :cascade do |t|
    t.string "avatar_url"
    t.text "bio"
    t.text "bio_html"
    t.string "company"
    t.datetime "created_at", null: false
    t.string "cross_domain_token"
    t.datetime "cross_domain_token_expires_at"
    t.string "email"
    t.datetime "github_data_updated_at"
    t.integer "github_id", null: false
    t.integer "github_repos_count"
    t.integer "github_stars_sum"
    t.text "hidden_repos"
    t.float "latitude"
    t.string "linkedin"
    t.string "locale"
    t.string "location"
    t.float "longitude"
    t.string "name"
    t.json "newsletters_opened", default: []
    t.json "newsletters_received", default: []
    t.string "normalized_location"
    t.boolean "open_to_work", default: false, null: false
    t.boolean "public", default: true, null: false
    t.integer "published_comments_count", default: 0, null: false
    t.integer "published_posts_count", default: 0, null: false
    t.integer "role", default: 0, null: false
    t.string "slug"
    t.integer "stars_gained", default: 0, null: false
    t.string "timezone"
    t.decimal "total_cost", precision: 12, scale: 6, default: "0.0", null: false
    t.string "twitter"
    t.boolean "unsubscribed_from_newsletter", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "website"
    t.index ["cross_domain_token"], name: "index_users_on_cross_domain_token", unique: true
    t.index ["email"], name: "index_users_on_email"
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["latitude", "longitude"], name: "index_users_on_coordinates"
    t.index ["normalized_location"], name: "index_users_on_normalized_location"
    t.index ["slug"], name: "index_users_on_slug"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "teams"
  add_foreign_key "articles", "users"
  add_foreign_key "chats", "models"
  add_foreign_key "chats", "teams"
  add_foreign_key "chats", "users"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "memberships", "teams"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "users", column: "invited_by_id"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "posts", "categories"
  add_foreign_key "posts", "users"
  add_foreign_key "posts_tags", "posts"
  add_foreign_key "posts_tags", "tags"
  add_foreign_key "projects", "users"
  add_foreign_key "rails_error_dashboard_cascade_patterns", "rails_error_dashboard_error_logs", column: "child_error_id"
  add_foreign_key "rails_error_dashboard_cascade_patterns", "rails_error_dashboard_error_logs", column: "parent_error_id"
  add_foreign_key "rails_error_dashboard_diagnostic_dumps", "rails_error_dashboard_applications", column: "application_id"
  add_foreign_key "rails_error_dashboard_error_comments", "rails_error_dashboard_error_logs", column: "error_log_id"
  add_foreign_key "rails_error_dashboard_error_logs", "rails_error_dashboard_applications", column: "application_id"
  add_foreign_key "rails_error_dashboard_error_occurrences", "rails_error_dashboard_error_logs", column: "error_log_id"
  add_foreign_key "reports", "posts"
  add_foreign_key "reports", "users"
  add_foreign_key "star_snapshots", "projects"
  add_foreign_key "team_languages", "languages"
  add_foreign_key "team_languages", "teams"
  add_foreign_key "tool_calls", "messages"
end
