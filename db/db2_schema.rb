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

ActiveRecord::Schema[8.1].define(version: 2026_06_13_120004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "timescaledb"

  create_table "entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.uuid "manufacturer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["manufacturer_id"], name: "index_entries_on_manufacturer_id"
  end

  create_table "manufacturers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "country"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_manufacturers_on_name", unique: true
    t.index ["tenant_id"], name: "index_manufacturers_on_tenant_id"
  end

  create_table "tenants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
  end

  add_foreign_key "entries", "manufacturers"
  add_foreign_key "manufacturers", "tenants"
end
