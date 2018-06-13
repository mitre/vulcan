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

ActiveRecord::Schema.define(version: 20180612210017) do

  create_table "ccis", force: :cascade do |t|
    t.string "cci"
  end

  create_table "ccis_nist_controls", id: false, force: :cascade do |t|
    t.integer "nist_control_id"
    t.integer "cci_id"
    t.index ["cci_id"], name: "index_ccis_nist_controls_on_cci_id"
    t.index ["nist_control_id"], name: "index_ccis_nist_controls_on_nist_control_id"
  end

  create_table "dod_agencies", force: :cascade do |t|
    t.string "name"
    t.string "phone_number"
    t.string "email"
    t.string "organization"
  end

  create_table "host_configs", force: :cascade do |t|
    t.string "encrypted_host"
    t.string "encrypted_host_iv"
    t.string "encrypted_user"
    t.string "encrypted_user_iv"
    t.string "encrypted_password"
    t.string "encrypted_password_iv"
    t.string "encrypted_transport_method"
    t.string "encrypted_transport_method_iv"
    t.string "encrypted_port"
    t.string "encrypted_port_iv"
    t.string "encrypted_aws_region"
    t.string "encrypted_aws_region_iv"
    t.string "encrypted_aws_profile"
    t.string "encrypted_aws_profile_iv"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_users_host_configs_on_user_id"
  end

  create_table "nist_controls", force: :cascade do |t|
    t.string "family"
    t.string "index"
    t.string "version"
    t.integer "nist_families_id"
    t.index ["nist_families_id"], name: "index_nist_controls_on_nist_families_id"
  end

  create_table "nist_controls_project_controls", id: false, force: :cascade do |t|
    t.integer "nist_control_id"
    t.integer "project_control_id"
    t.index ["nist_control_id"], name: "index_nist_controls_project_controls_on_nist_control_id"
    t.index ["project_control_id"], name: "index_nist_controls_project_controls_on_project_control_id"
  end

  create_table "nist_controls_srg_controls", id: false, force: :cascade do |t|
    t.integer "nist_control_id"
    t.integer "srg_control_id"
    t.index ["nist_control_id"], name: "index_nist_controls_srg_controls_on_nist_control_id"
    t.index ["srg_control_id"], name: "index_nist_controls_srg_controls_on_srg_control_id"
  end

  create_table "nist_families", force: :cascade do |t|
    t.string "family"
    t.string "version"
    t.string "short_title"
    t.string "long_title"
  end

  create_table "project_control_histories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "project_control_attr"
    t.string "comment"
    t.string "project_control_id"
    t.integer "user_id"
    t.integer "is_reply_to", default: 0
    t.index ["project_control_id"], name: "index_project_control_histories_on_project_control_id"
    t.index ["user_id"], name: "index_project_control_histories_on_user_id"
  end

  create_table "project_controls", force: :cascade do |t|
    t.string "encrypted_title"
    t.string "encrypted_title_iv"
    t.string "encrypted_description"
    t.string "encrypted_description_iv"
    t.string "encrypted_impact"
    t.string "encrypted_impact_iv"
    t.string "encrypted_code"
    t.string "encrypted_code_iv"
    t.string "encrypted_control_id"
    t.string "encrypted_control_id_iv"
    t.string "encrypted_checktext"
    t.string "encrypted_checktext_iv"
    t.string "encrypted_fixtext"
    t.string "encrypted_fixtext_iv"
    t.string "encrypted_justification"
    t.string "encrypted_justification_iv"
    t.string "encrypted_status"
    t.string "encrypted_status_iv"
    t.string "sl_ref"
    t.string "sl_line"
    t.text "tag"
    t.text "srg_title_id"
    t.integer "project_id"
    t.index ["project_id"], name: "index_project_controls_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "encrypted_name"
    t.string "encrypted_name_iv"
    t.string "encrypted_title"
    t.string "encrypted_title_iv"
    t.string "encrypted_maintainer"
    t.string "encrypted_maintainer_iv"
    t.string "encrypted_copyright"
    t.string "encrypted_copyright_iv"
    t.string "encrypted_copyright_email"
    t.string "encrypted_copyright_email_iv"
    t.string "encrypted_license"
    t.string "encrypted_license_iv"
    t.string "encrypted_summary"
    t.string "encrypted_summary_iv"
    t.string "encrypted_version"
    t.string "encrypted_version_iv"
    t.integer "dod_agencies_id"
    t.index ["dod_agencies_id"], name: "index_projects_on_dod_agencies_id"
  end

  create_table "projects_srgs", force: :cascade do |t|
    t.integer "srg_id"
    t.integer "project_id"
    t.index ["project_id"], name: "index_projects_srgs_on_project_id"
    t.index ["srg_id"], name: "index_projects_srgs_on_srg_id"
  end

  create_table "projects_users", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "project_id"
    t.index ["project_id"], name: "index_users_projects_on_project_id"
    t.index ["user_id"], name: "index_users_projects_on_user_id"
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
    t.integer "srg_id"
    t.index ["srg_id"], name: "index_srg_controls_on_srg_id"
  end

  create_table "srgs", force: :cascade do |t|
    t.string "title"
    t.string "description"
    t.string "publisher"
    t.string "published"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "profile_pic_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end
end
