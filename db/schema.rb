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

ActiveRecord::Schema.define(version: 2022_08_15_180252) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "additional_answers", force: :cascade do |t|
    t.bigint "rule_id", null: false
    t.bigint "additional_question_id", null: false
    t.text "answer"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["additional_question_id"], name: "index_additional_answers_on_additional_question_id"
    t.index ["rule_id", "additional_question_id"], name: "index_additional_answers_on_rule_id_and_additional_question_id", unique: true
    t.index ["rule_id"], name: "index_additional_answers_on_rule_id"
  end

  create_table "additional_questions", force: :cascade do |t|
    t.string "name", null: false
    t.string "question_type", null: false
    t.string "options", default: [], array: true
    t.bigint "component_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["component_id", "name"], name: "index_additional_questions_on_component_id_and_name", unique: true
    t.index ["component_id"], name: "index_additional_questions_on_component_id"
  end

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
    t.integer "audited_user_id"
    t.string "audited_username"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "base_rules", force: :cascade do |t|
    t.boolean "locked", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "status", default: "Not Yet Determined"
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
    t.bigint "review_requestor_id"
    t.bigint "component_id"
    t.boolean "changes_requested", default: false
    t.string "type"
    t.bigint "srg_rule_id"
    t.bigint "security_requirements_guide_id"
    t.text "inspec_control_body"
    t.text "inspec_control_file"
    t.text "inspec_control_body_lang", default: "ruby"
    t.text "inspec_control_file_lang", default: "ruby"
    t.datetime "deleted_at"
    t.index ["component_id"], name: "index_base_rules_on_component_id"
    t.index ["deleted_at"], name: "index_base_rules_on_deleted_at"
    t.index ["review_requestor_id"], name: "index_base_rules_on_review_requestor_id"
    t.index ["rule_id", "component_id"], name: "rule_id_and_component_id", unique: true
    t.index ["security_requirements_guide_id"], name: "index_base_rules_on_security_requirements_guide_id"
    t.index ["srg_rule_id"], name: "index_base_rules_on_srg_rule_id"
  end

  create_table "checks", force: :cascade do |t|
    t.bigint "base_rule_id"
    t.string "system"
    t.string "content_ref_name"
    t.string "content_ref_href"
    t.text "content"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["base_rule_id"], name: "index_checks_on_base_rule_id"
  end

  create_table "component_metadata", force: :cascade do |t|
    t.json "data", null: false
    t.bigint "component_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["component_id"], name: "by_component_id", unique: true
  end

  create_table "components", force: :cascade do |t|
    t.bigint "project_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.bigint "component_id"
    t.string "prefix"
    t.bigint "security_requirements_guide_id"
    t.string "name"
    t.boolean "released", default: false, null: false
    t.integer "memberships_count", default: 0
    t.integer "rules_count", default: 0
    t.string "admin_name"
    t.string "admin_email"
    t.boolean "advanced_fields", default: false
    t.integer "version"
    t.integer "release"
    t.string "title"
    t.text "description"
    t.index ["component_id"], name: "index_components_on_component_id"
    t.index ["project_id"], name: "index_components_on_project_id"
  end

  create_table "disa_rule_descriptions", force: :cascade do |t|
    t.bigint "base_rule_id"
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
    t.boolean "mitigations_available"
    t.boolean "poam_available"
    t.text "poam"
    t.index ["base_rule_id"], name: "index_disa_rule_descriptions_on_base_rule_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "membership_id"
    t.string "role", default: "viewer", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "membership_type"
    t.index ["membership_id"], name: "index_memberships_on_membership_id"
    t.index ["user_id", "membership_type", "membership_id"], name: "by_user_and_membership", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
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
    t.integer "memberships_count", default: 0
    t.string "admin_name"
    t.string "admin_email"
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
    t.bigint "base_rule_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "rule_id"
    t.string "action"
    t.text "comment"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["rule_id"], name: "index_reviews_on_rule_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "rule_descriptions", force: :cascade do |t|
    t.bigint "base_rule_id"
    t.text "description"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["base_rule_id"], name: "index_rule_descriptions_on_base_rule_id"
  end

  create_table "rule_satisfactions", id: false, force: :cascade do |t|
    t.bigint "rule_id"
    t.bigint "satisfied_by_rule_id"
    t.index ["rule_id", "satisfied_by_rule_id"], name: "index_rule_satisfactions_on_rule_id_and_satisfied_by_rule_id", unique: true
    t.index ["satisfied_by_rule_id", "rule_id"], name: "index_rule_satisfactions_on_satisfied_by_rule_id_and_rule_id", unique: true
  end

  create_table "security_requirements_guides", force: :cascade do |t|
    t.string "srg_id", null: false
    t.string "title", null: false
    t.string "version", null: false
    t.xml "xml", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.date "release_date"
    t.index ["srg_id", "version"], name: "security_requirements_guides_id_and_version", unique: true
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

  add_foreign_key "additional_answers", "additional_questions"
  add_foreign_key "additional_answers", "base_rules", column: "rule_id"
  add_foreign_key "base_rules", "base_rules", column: "srg_rule_id"
  add_foreign_key "base_rules", "components"
  add_foreign_key "base_rules", "security_requirements_guides"
  add_foreign_key "base_rules", "users", column: "review_requestor_id"
  add_foreign_key "components", "components"
  add_foreign_key "memberships", "users"
end
