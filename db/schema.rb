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

ActiveRecord::Schema[8.0].define(version: 2026_03_30_192930) do
  create_table "endpoint_monitoring_endpoints", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "endpoint_monitoring_group_id", null: false
    t.string "name", null: false
    t.string "host", null: false
    t.string "monitoring_mode", null: false
    t.integer "port"
    t.integer "latency_critical"
    t.integer "latency_warning"
    t.integer "response_time"
    t.json "acceptable_response_codes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_monitoring_group_id"], name: "idx_on_endpoint_monitoring_group_id_1f2ab4005c"
    t.index ["host"], name: "index_endpoint_monitoring_endpoints_on_host"
    t.index ["monitoring_mode"], name: "index_endpoint_monitoring_endpoints_on_monitoring_mode"
    t.index ["name"], name: "index_endpoint_monitoring_endpoints_on_name"
  end

  create_table "endpoint_monitoring_groups", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "group_type"
    t.integer "user_id"
    t.integer "organisation_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_all_devices", default: false
    t.boolean "is_all_networks", default: false
    t.boolean "is_all_tags", default: false
    t.index ["group_type"], name: "index_endpoint_monitoring_groups_on_group_type"
    t.index ["name"], name: "index_endpoint_monitoring_groups_on_name"
    t.index ["user_id", "created_at"], name: "index_endpoint_monitoring_groups_on_user_and_created_at"
  end

  create_table "ep_config_mappings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "resourceable_type", null: false
    t.bigint "resourceable_id", null: false
    t.bigint "endpoint_monitoring_group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint_monitoring_group_id"], name: "index_ep_config_mappings_on_endpoint_monitoring_group_id"
    t.index ["resourceable_type", "resourceable_id", "endpoint_monitoring_group_id"], name: "index_ep_config_on_type_id_and_group"
    t.index ["resourceable_type", "resourceable_id"], name: "index_ep_config_mappings_on_resource"
  end

  add_foreign_key "endpoint_monitoring_endpoints", "endpoint_monitoring_groups"
end
