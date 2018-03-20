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

ActiveRecord::Schema.define(version: 20180320151720) do

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

  create_table "profiles", force: :cascade do |t|
    t.string "name"
    t.string "title"
    t.string "maintainer"
    t.string "copyright"
    t.string "copyright_email"
    t.string "license"
    t.string "summary"
    t.string "version"
    t.string "sha256"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "srg_controls", force: :cascade do |t|
    t.integer "srg_id"
    t.string "controlId"
    t.string "severity"
    t.string "title"
    t.string "description"
    t.string "iacontrols"
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
  end

end
