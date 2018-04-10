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

ActiveRecord::Schema.define(version: 20180406183323) do

  create_table "project_controls", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.float "impact"
    t.string "code"
    t.string "control_id"
    t.string "sl_ref"
    t.string "sl_line"
    t.text "tag"
    t.text "checktext"
    t.text "fixtext"
    t.text "justification"
    t.text "status"
    t.text "srg_title_id"
    t.references(:project, index: true)
  end

  create_table "nist_controls_project_controls", id: false, force: :cascade do |t|
    t.references(:nist_control, index: true)
    t.references(:project_control, index: true)
  end
  
  create_table "nist_controls_srg_controls", id: false, force: :cascade do |t|
    t.references(:nist_control, index: true)
    t.references(:srg_control, index: true)
  end
  
  create_table "ccis_nist_controls", id: false, force: :cascade do |t|
    t.references(:nist_control, index: true)
    t.references(:cci, index: true)
  end

  create_table "nist_families", force: :cascade do |t|
    t.string "family"
    t.string "version"
    t.string "short_title"
    t.string "long_title"
  end
  
  create_table "ccis", force: :cascade do |t|
    t.string "cci"
  end
  
  create_table "nist_controls", force: :cascade do |t|
    t.string "family"
    t.string "index"
    t.string "version"
    t.references(:nist_families, index: true)
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.string "title"
    t.string "maintainer"
    t.string "copyright"
    t.string "copyright_email"
    t.string "license"
    t.string "summary"
    t.string "version"
  end
  
  create_table "projects_srgs", force: :cascade do |t|
    t.references(:srg, index: true)
    t.references(:project, index: true)
  end

  create_table "srg_controls", force: :cascade do |t|
    t.string "control_id"
    t.string "severity"
    t.string "title"
    t.string "description"
    t.string "nistFamilies"
    t.string "ruleID"
    t.string "fixid"
    t.string "fixtext"
    t.string "checkid"
    t.string "checktext"
    t.text "srg_title_id"
    t.references(:srg, index: true)
    # t.index ["srgs_id"], name: "index_srg_controls_on_srgs_id"
  end

  create_table "srgs", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "publisher"
    t.string "published"
  end

end
