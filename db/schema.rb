# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180329165522) do

  create_table "controls", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.float "impact"
    t.string "code"
    t.string "control_id"
    t.string "sl_ref"
    t.string "sl_line"
    t.text "tag"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "nist_families", force: :cascade do |t|
    t.string "family"
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "srg_control_id"
    t.index ["srg_control_id"], name: "index_nist_families_on_srg_control_id"
  end

# Could not dump table "profiles" because of following StandardError
#   Unknown type 'has_many' for column 'srg_ids'

  create_table "srg_controls", force: :cascade do |t|
    t.integer "srg_id"
    t.string "controlId"
    t.string "severity"
    t.string "title"
    t.string "description"
    t.string "nistFamilies"
    t.string "ruleID"
    t.string "fixid"
    t.string "fixtext"
    t.string "checkid"
    t.string "checktext"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["srg_id"], name: "index_srg_controls_on_srg_id"
  end

  create_table "srgs", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "publisher"
    t.string "published"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "control_id"
    t.index ["control_id"], name: "index_tags_on_control_id"
  end

end
