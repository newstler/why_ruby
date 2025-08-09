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

ActiveRecord::Schema[8.1].define(version: 2025_08_09_160805) do
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
    t.string "name", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["position"], name: "index_categories_on_position", unique: true
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

  create_table "posts", id: :string, default: -> { "ULID()" }, force: :cascade do |t|
    t.string "category_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.boolean "needs_admin_review", default: false, null: false
    t.integer "pin_position"
    t.boolean "published", default: false, null: false
    t.integer "reports_count", default: 0, null: false
    t.text "summary"
    t.string "title", null: false
    t.string "title_image_url"
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "user_id", null: false
    t.index ["category_id"], name: "index_posts_on_category_id"
    t.index ["created_at"], name: "index_posts_on_created_at"
    t.index ["needs_admin_review"], name: "index_posts_on_needs_admin_review"
    t.index ["pin_position"], name: "index_posts_on_pin_position", unique: true, where: "pin_position IS NOT NULL"
    t.index ["published"], name: "index_posts_on_published"
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
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
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
    t.string "twitter"
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.string "website"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["github_id"], name: "index_users_on_github_id", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "posts", "categories"
  add_foreign_key "posts", "users"
  add_foreign_key "posts_tags", "posts"
  add_foreign_key "posts_tags", "tags"
  add_foreign_key "reports", "posts"
  add_foreign_key "reports", "users"
end
