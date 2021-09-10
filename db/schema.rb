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

ActiveRecord::Schema.define(version: 2021_09_10_000716) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "checks", force: :cascade do |t|
    t.bigint "rule_id"
    t.string "system"
    t.string "content_ref_name"
    t.string "content_ref_href"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rule_id"], name: "index_checks_on_rule_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "rule_id"
    t.text "body"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rule_id"], name: "index_comments_on_rule_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "disa_rule_descriptions", force: :cascade do |t|
    t.bigint "rule_id"
    t.text "vuln_discussion"
    t.text "false_positives"
    t.text "false_negatives"
    t.boolean "documentable"
    t.text "mitigations"
    t.text "severity_override_guidance"
    t.text "potential_impacts"
    t.text "third_party_tools"
    t.text "mitigation_control"
    t.text "responsibility"
    t.text "ia_controls"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rule_id"], name: "index_disa_rule_descriptions_on_rule_id"
  end

  create_table "project_members", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "project_id"
    t.string "role", default: "author", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "index_project_members_on_project_id"
    t.index ["user_id", "project_id"], name: "by_user_and_project", unique: true
    t.index ["user_id"], name: "index_project_members_on_user_id"
  end

  create_table "project_metadata", force: :cascade do |t|
    t.json "data", null: false
    t.bigint "project_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["project_id"], name: "by_project_id", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "project_members_count", default: 0
  end

  create_table "references", force: :cascade do |t|
    t.string "contributor"
    t.string "coverage"
    t.string "creator"
    t.string "date"
    t.string "description"
    t.string "format"
    t.string "identifier"
    t.string "language"
    t.string "publisher"
    t.string "relation"
    t.string "rights"
    t.string "source"
    t.string "subject"
    t.string "title"
    t.string "reference_type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "rule_id"
  end

  create_table "rule_descriptions", force: :cascade do |t|
    t.bigint "rule_id"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rule_id"], name: "index_rule_descriptions_on_rule_id"
  end

  create_table "rules", force: :cascade do |t|
    t.boolean "locked", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "project_id"
    t.string "status"
    t.text "status_justification"
    t.text "artifact_description"
    t.text "vendor_comments"
    t.string "rule_id", null: false
    t.string "rule_severity"
    t.string "rule_weight"
    t.string "version"
    t.string "title"
    t.string "ident"
    t.string "ident_system", default: "http://iase.disa.mil/cci"
    t.text "fixtext"
    t.string "fixtext_fixref"
    t.string "fix_id"
    t.index ["project_id"], name: "index_rules_on_project_id"
    t.index ["rule_id", "project_id"], name: "rules_rule_id_project_id_index", unique: true
  end

  create_table "security_requirements_guides", force: :cascade do |t|
    t.string "srg_id", null: false
    t.string "title", null: false
    t.string "version", null: false
    t.xml "xml", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.boolean "admin", default: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "project_members", "projects"
  add_foreign_key "project_members", "users"
  add_foreign_key "rules", "projects"
end
