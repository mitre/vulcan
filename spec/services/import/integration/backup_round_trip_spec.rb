# frozen_string_literal: true

require 'rails_helper'

# ===========================================================================
# REQUIREMENT: A JSON archive backup exported from one project must be
# importable into another project with 100% data fidelity. Every rule
# column, nested record, satisfaction relationship, and review must survive
# the round-trip unchanged.
#
# This is the golden contract test — if it passes, backup/restore works.
# ===========================================================================

# Extracted to avoid immutable array literals in loops (Performance/CollectionLiteralInLoop)
RULE_COMPARE_FIELDS = %i[status status_justification artifact_description vendor_comments
                         title fixtext fixtext_fixref fix_id
                         rule_severity rule_weight version
                         ident ident_system locked changes_requested
                         inspec_control_body inspec_control_file
                         inspec_control_body_lang inspec_control_file_lang
                         legacy_ids vuln_id].freeze

DISA_RULE_DESC_FIELDS = %w[vuln_discussion false_positives false_negatives documentable mitigations
                           severity_override_guidance potential_impacts third_party_tools
                           mitigation_control responsibility ia_controls].freeze

CHECK_FIELDS = %w[system content_ref_name content_ref_href content].freeze

ROUNDTRIP_BACKUP_FILENAME = 'project-backup.zip'

RSpec.describe 'JSON Archive Backup Round-Trip' do
  # ------------------------------------------------------------------
  # EXPENSIVE SETUP — source data created ONCE, shared via savepoints.
  # Each example gets its own target_project (cheap) for import.
  # ------------------------------------------------------------------
  let_it_be(:source_project, reload: true) { create(:project, name: 'Source Project') }
  let_it_be(:review_user) { create(:user) }
  let_it_be(:source_component) do
    create(:component,
           project: source_project,
           name: 'Round Trip Test',
           prefix: 'RTTT-01',
           title: 'Round Trip Test Component',
           description: 'Tests full-fidelity backup/restore',
           admin_name: 'Test Admin',
           admin_email: 'admin@test.org',
           advanced_fields: true,
           version: 2,
           release: 3)
  end

  # Enrich source data ONCE (part of let_it_be lifecycle)
  let_it_be(:_enrichment) do
    rules = source_component.rules.order(:rule_id).to_a

    # Set varied statuses
    rules[0..2].each { |r| r.update_columns(status: 'Applicable - Configurable') }
    rules[3]&.update_columns(status: 'Applicable - Inherently Meets')
    rules[4]&.update_columns(status: 'Not Applicable')

    # Add user-authored content to first rule
    rules[0].update_columns(
      fixtext: 'Configure the system to enforce password complexity requirements.',
      vendor_comments: 'Vendor confirms this setting is supported in version 4.0+.',
      status_justification: 'This control is configurable via /etc/security/pwquality.conf.',
      artifact_description: 'Evidence: screenshot of configuration file',
      locked: true,
      inspec_control_file: "control 'SV-000001' do\n  impact 0.5\n  describe file('/etc/security/pwquality.conf') do\n    it { should exist }\n  end\nend",
      inspec_control_file_lang: 'ruby'
    )

    # Add satisfactions
    RuleSatisfaction.create!(rule_id: rules[5].id, satisfied_by_rule_id: rules[0].id)

    # Add reviews
    Review.create!(user: review_user, rule: rules[1], action: 'lock_control', comment: 'Locking for release review')
    rules[1].reload
    Review.create!(user: review_user, rule: rules[1], action: 'unlock_control', comment: 'Unlocking after review')

    # Add additional question + answer
    question = source_component.additional_questions.create!(
      name: 'Deployment Environment', question_type: 'dropdown',
      options: %w[Production Staging Development]
    )
    AdditionalAnswer.create!(rule: rules[0], additional_question: question, answer: 'Production')
  end

  # Pre-generate the backup ZIP once (the export is deterministic for unchanged source data)
  let_it_be(:source_backup_zip) do
    Export::Base.new(
      exportable: source_component.reload,
      mode: :backup,
      format: :json_archive
    ).call.data
  end

  # Load the actual SRG (bypass select scope on based_on)
  let(:srg) { SecurityRequirementsGuide.find(source_component.security_requirements_guide_id) }

  # Per-example: cheap target project for import
  let(:target_project) { create(:project, name: 'Target Project') }

  # ---------- The golden round-trip test ----------

  describe 'export then import' do
    # Use pre-generated backup ZIP (export is deterministic, no need to re-export per example)
    let(:import_result) do
      Import::JsonArchiveImporter.new(
        zip_file: source_backup_zip,
        project: target_project,
        include_reviews: true
      ).call
    end

    let(:imported_component) do
      target_project.components.find_by(name: source_component.name)
    end

    it 'succeeds' do
      expect(import_result).to be_success
      expect(import_result.errors).to be_empty
    end

    it 'preserves component attributes' do
      import_result
      expect(imported_component).to be_present

      %i[name prefix version release title description admin_name admin_email advanced_fields].each do |attr|
        expect(imported_component.send(attr)).to eq(source_component.send(attr)),
                                                 "Component.#{attr}: expected #{source_component.send(attr).inspect}, got #{imported_component.send(attr).inspect}"
      end
    end

    it 'links to the same SRG' do
      import_result
      expect(imported_component.security_requirements_guide_id).to eq(source_component.security_requirements_guide_id)
    end

    it 'preserves rule count' do
      import_result
      expect(imported_component.rules.count).to eq(source_component.rules.count)
    end

    it 'preserves all rule fields' do
      import_result
      source_rules = source_component.rules.order(:rule_id).to_a
      imported_rules = imported_component.rules.order(:rule_id).to_a

      source_rules.zip(imported_rules).each do |src, imp|
        # Business key
        expect(imp.rule_id).to eq(src.rule_id)

        # User-authored fields
        RULE_COMPARE_FIELDS.each do |field|
          expect(imp.send(field)).to eq(src.send(field)),
                                     "Rule #{src.rule_id}.#{field}: expected #{src.send(field).inspect}, got #{imp.send(field).inspect}"
        end

        # SRG rule link preserved by version (DB id may differ for duplicate SRG versions)
        expect(imp.srg_rule&.version).to eq(src.srg_rule&.version),
                                         "Rule #{src.rule_id} srg_rule version: expected #{src.srg_rule&.version}, got #{imp.srg_rule&.version}"
      end
    end

    it 'preserves disa_rule_descriptions' do
      import_result
      source_rules = source_component.rules.includes(:disa_rule_descriptions).order(:rule_id)
      imported_rules = imported_component.rules.includes(:disa_rule_descriptions).order(:rule_id)

      source_rules.zip(imported_rules).each do |src, imp|
        expect(imp.disa_rule_descriptions.size).to eq(src.disa_rule_descriptions.size),
                                                   "Rule #{src.rule_id} disa_rule_descriptions count mismatch"

        src.disa_rule_descriptions.zip(imp.disa_rule_descriptions).each do |src_drd, imp_drd|
          DISA_RULE_DESC_FIELDS.each do |field|
            expect(imp_drd.send(field)).to eq(src_drd.send(field)),
                                           "Rule #{src.rule_id} disa_rule_description.#{field} mismatch"
          end
        end
      end
    end

    it 'preserves checks' do
      import_result
      source_rules = source_component.rules.includes(:checks).order(:rule_id)
      imported_rules = imported_component.rules.includes(:checks).order(:rule_id)

      source_rules.zip(imported_rules).each do |src, imp|
        expect(imp.checks.size).to eq(src.checks.size)
        src.checks.zip(imp.checks).each do |src_c, imp_c|
          CHECK_FIELDS.each do |field|
            expect(imp_c.send(field)).to eq(src_c.send(field))
          end
        end
      end
    end

    it 'preserves references' do
      import_result
      source_rules = source_component.rules.includes(:references).order(:rule_id)
      imported_rules = imported_component.rules.includes(:references).order(:rule_id)

      source_rules.zip(imported_rules).each do |src, imp|
        expect(imp.references.size).to eq(src.references.size)
      end
    end

    it 'rebuilds satisfaction relationships' do
      import_result
      source_sats = RuleSatisfaction.where(rule_id: source_component.rule_ids)
      imported_sats = RuleSatisfaction.where(rule_id: imported_component.rule_ids)

      expect(imported_sats.count).to eq(source_sats.count)

      # Verify by rule_id string mapping
      source_sats.each do |src_sat|
        src_rule_id = Rule.find(src_sat.rule_id).rule_id
        src_satisfied_by_id = Rule.find(src_sat.satisfied_by_rule_id).rule_id

        imported_rule = imported_component.rules.find_by(rule_id: src_rule_id)
        imported_satisfied_by = imported_component.rules.find_by(rule_id: src_satisfied_by_id)

        expect(imported_rule).to be_present, "Expected imported rule with rule_id #{src_rule_id}"
        expect(imported_satisfied_by).to be_present, "Expected imported satisfied_by with rule_id #{src_satisfied_by_id}"

        imp_sat = RuleSatisfaction.find_by(
          rule_id: imported_rule.id,
          satisfied_by_rule_id: imported_satisfied_by.id
        )
        expect(imp_sat).to be_present,
                           "Missing satisfaction: #{src_rule_id} -> #{src_satisfied_by_id}"
      end
    end

    it 'imports reviews with attribution' do
      import_result
      source_reviews = Review.where(rule_id: source_component.rule_ids).order(:created_at)
      imported_reviews = Review.where(rule_id: imported_component.rule_ids).order(:created_at)

      expect(imported_reviews.count).to eq(source_reviews.count)

      source_reviews.zip(imported_reviews).each do |src, imp|
        expect(imp.action).to eq(src.action)
        expect(imp.comment).to eq(src.comment)
        expect(imp.user_id).to eq(src.user_id) # same user resolved by email
      end
    end

    it 'preserves additional answers' do
      import_result
      source_rule = source_component.rules.first
      imported_rule = imported_component.rules.find_by(rule_id: source_rule.rule_id)

      source_answers = source_rule.additional_answers.includes(:additional_question)
      imported_answers = imported_rule.additional_answers.includes(:additional_question)

      expect(imported_answers.count).to eq(source_answers.count)

      source_answers.zip(imported_answers).each do |src, imp|
        expect(imp.answer).to eq(src.answer)
        expect(imp.additional_question.name).to eq(src.additional_question.name)
      end
    end

    it 'preserves timestamps within 1 second' do
      import_result
      source_rules = source_component.rules.order(:rule_id)
      imported_rules = imported_component.rules.order(:rule_id)

      source_rules.zip(imported_rules).each do |src, imp|
        # ISO8601 serialization truncates to seconds
        expect(imp.created_at).to be_within(1.second).of(src.created_at)
        expect(imp.updated_at).to be_within(1.second).of(src.updated_at)
      end
    end

    it 'reports accurate summary counts' do
      result = import_result
      expect(result.summary[:components_imported]).to eq(1)
      expect(result.summary[:rules_imported]).to eq(source_component.rules.count)
      expect(result.summary[:satisfactions_imported]).to eq(1)
      expect(result.summary[:reviews_imported]).to eq(2)
    end
  end

  # ---------- Edge cases ----------

  describe 'edge cases' do
    describe 'empty component (no user-authored data)' do
      let(:empty_component) { create(:component, project: source_project, name: 'Empty Component') }

      it 'round-trips successfully' do
        zip = Export::Base.new(
          exportable: empty_component, mode: :backup, format: :json_archive
        ).call.data

        result = Import::JsonArchiveImporter.new(
          zip_file: zip, project: target_project
        ).call

        expect(result).to be_success
        imported = target_project.components.find_by(name: 'Empty Component')
        expect(imported).to be_present
        expect(imported.rules.count).to eq(empty_component.rules.count)
      end
    end

    describe 'multi-component project backup' do
      let!(:second_component) do
        create(:component, project: source_project, name: 'Second Component')
      end

      it 'imports all components' do
        zip = Export::Base.new(
          exportable: source_project,
          mode: :backup,
          format: :json_archive,
          zip_filename: ROUNDTRIP_BACKUP_FILENAME
        ).call.data

        result = Import::JsonArchiveImporter.new(
          zip_file: zip, project: target_project
        ).call

        expect(result).to be_success
        expect(result.summary[:components_imported]).to eq(2)
        expect(target_project.components.pluck(:name)).to contain_exactly(
          source_component.name, second_component.name
        )
      end
    end

    describe 'rule with all optional fields populated' do
      before do
        rule = source_component.rules.order(:rule_id).first
        rule.update_columns(
          status_justification: 'Justified because of X',
          artifact_description: 'See artifact: /path/to/evidence',
          vendor_comments: 'Vendor confirms compliance',
          vuln_id: 'V-123456',
          inspec_control_body: "control 'V-123456' do\n  impact 0.5\nend"
        )
      end

      it 'preserves all optional fields through round-trip' do
        zip = Export::Base.new(
          exportable: source_component, mode: :backup, format: :json_archive
        ).call.data

        result = Import::JsonArchiveImporter.new(
          zip_file: zip, project: target_project
        ).call

        expect(result).to be_success
        original = source_component.rules.order(:rule_id).first
        imported = target_project.components.find_by(name: source_component.name)
                                 .rules.find_by(rule_id: original.rule_id)

        expect(imported.status_justification).to eq('Justified because of X')
        expect(imported.artifact_description).to eq('See artifact: /path/to/evidence')
        expect(imported.vendor_comments).to eq('Vendor confirms compliance')
        expect(imported.vuln_id).to eq('V-123456')
        expect(imported.inspec_control_body).to eq("control 'V-123456' do\n  impact 0.5\nend")
      end
    end

    describe 'membership round-trip' do
      let(:member_user) { create(:user, email: 'member@test.org', name: 'Team Member') }

      before do
        Membership.create!(user: member_user, membership: source_project, role: 'author')
      end

      it 'restores memberships when include_memberships is true' do
        zip = Export::Base.new(
          exportable: source_project,
          mode: :backup,
          format: :json_archive,
          zip_filename: 'membership-backup.zip'
        ).call.data

        result = Import::JsonArchiveImporter.new(
          zip_file: zip, project: target_project,
          include_reviews: true, include_memberships: true
        ).call

        expect(result).to be_success
        expect(result.summary[:memberships_imported]).to be >= 1
        expect(Membership.exists?(user: member_user, membership: target_project, membership_type: 'Project')).to be true
      end

      it 'warns for missing users during membership import' do
        ghost = create(:user, email: 'ghost@test.org')
        Membership.create!(user: ghost, membership: source_project, role: 'viewer')

        zip = Export::Base.new(
          exportable: source_project,
          mode: :backup,
          format: :json_archive,
          zip_filename: 'membership-backup.zip'
        ).call.data

        ghost.memberships.delete_all
        ghost.destroy!

        result = Import::JsonArchiveImporter.new(
          zip_file: zip, project: target_project,
          include_reviews: true, include_memberships: true
        ).call

        expect(result).to be_success
        expect(result.warnings).to include(a_string_matching(/ghost@test\.org.*not found/))
      end
    end

    describe 'bidirectional satisfactions' do
      let(:bidir_project) { create(:project, name: 'Bidir Source') }
      let(:bidir_target) { create(:project, name: 'Bidir Target') }
      let!(:bidir_component) { create(:component, project: bidir_project) }

      before do
        rules = bidir_component.rules.order(:rule_id).to_a
        # A satisfies B AND B satisfies A (bidirectional)
        RuleSatisfaction.create!(rule_id: rules[1].id, satisfied_by_rule_id: rules[0].id)
        RuleSatisfaction.create!(rule_id: rules[0].id, satisfied_by_rule_id: rules[1].id)
      end

      it 'preserves both directions' do
        zip = Export::Base.new(
          exportable: bidir_component, mode: :backup, format: :json_archive
        ).call.data

        result = Import::JsonArchiveImporter.new(
          zip_file: zip, project: bidir_target
        ).call

        expect(result).to be_success
        imported_sats = RuleSatisfaction.where(rule_id: bidir_target.components.first.rule_ids)
        expect(imported_sats.count).to eq(2)
      end
    end

    describe 'component filtering' do
      let!(:second_component) do
        create(:component, project: source_project, name: 'Second Component')
      end

      let(:project_zip) do
        Export::Base.new(
          exportable: source_project,
          mode: :backup,
          format: :json_archive,
          zip_filename: ROUNDTRIP_BACKUP_FILENAME
        ).call.data
      end

      it 'imports only selected components' do
        filter = { source_component.name => source_component.name }
        result = Import::JsonArchiveImporter.new(
          zip_file: project_zip,
          project: target_project,
          component_filter: filter
        ).call

        expect(result).to be_success
        expect(result.summary[:components_imported]).to eq(1)
        expect(target_project.components.pluck(:name)).to contain_exactly(source_component.name)
      end

      it 'renames component via filter' do
        renamed = "#{source_component.name} (restored)"
        filter = { source_component.name => renamed }
        result = Import::JsonArchiveImporter.new(
          zip_file: project_zip,
          project: target_project,
          component_filter: filter
        ).call

        expect(result).to be_success
        expect(target_project.components.find_by(name: renamed)).to be_present
      end

      it 'handles conflicting component with rename' do
        # Create conflict in target
        create(:component, project: target_project,
                           name: source_component.name,
                           based_on: source_component.based_on)

        renamed = "#{source_component.name} (restored)"
        filter = { source_component.name => renamed, second_component.name => second_component.name }
        result = Import::JsonArchiveImporter.new(
          zip_file: project_zip,
          project: target_project,
          component_filter: filter
        ).call

        expect(result).to be_success
        expect(target_project.components.find_by(name: renamed)).to be_present
        expect(target_project.components.find_by(name: second_component.name)).to be_present
      end
    end

    describe 'create-from-backup round-trip' do
      it 'preserves all data through project creation' do
        zip = Export::Base.new(
          exportable: source_project.reload,
          mode: :backup,
          format: :json_archive,
          zip_filename: ROUNDTRIP_BACKUP_FILENAME
        ).call.data

        new_project = Project.create!(
          name: 'Created From Backup',
          memberships_attributes: [{ user: review_user, role: 'admin' }]
        )

        result = Import::JsonArchiveImporter.new(
          zip_file: zip,
          project: new_project,
          include_reviews: true
        ).call

        expect(result).to be_success
        expect(result.summary[:components_imported]).to eq(1)
        imported = new_project.components.find_by(name: source_component.name)
        expect(imported).to be_present
        expect(imported.rules.count).to eq(source_component.rules.count)
      end
    end
  end

  private

  # Enrich factory-created rules with realistic user-authored data
end
