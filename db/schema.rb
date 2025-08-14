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

ActiveRecord::Schema[8.1].define(version: 2025_08_13_235819) do
  create_table "active_storage_attachments", id: :string, force: :cascade do |t|
    t.string "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :string, force: :cascade do |t|
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

  create_table "active_storage_variant_records", id: :string, force: :cascade do |t|
    t.string "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "categories", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
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

  create_table "comments", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
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

  create_table "posts", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
    t.string "category_id", null: false
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

  create_table "reports", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
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

  create_table "tags", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug"
  end

  create_table "users", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
    t.string "avatar_url"
    t.text "bio"
    t.string "company"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "github_data_updated_at"
    t.integer "github_id", null: false
    t.text "github_repos"
    t.string "linkedin"
    t.string "location"
    t.string "name"
    t.integer "published_comments_count", default: 0, null: false
    t.integer "published_posts_count", default: 0, null: false
    t.integer "role", default: 0, null: false
    t.string "slug"
    t.string "twitter"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "website"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["slug"], name: "index_users_on_slug"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "posts", "categories"
  add_foreign_key "posts", "users"
  add_foreign_key "posts_tags", "posts"
  add_foreign_key "posts_tags", "tags"
  add_foreign_key "reports", "posts"
  add_foreign_key "reports", "users"
end
