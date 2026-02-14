# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  let(:status_applicable) { 'Applicable - Configurable' }

  before do
    srg_xml = Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    # Create projects
    @p1 = Project.create(name: 'Photon OS 3')
    @p2 = Project.create(name: 'Photon OS 3.1')

    # Create components
    @p1_c1 = Component.create(project: @p1, version: 'Photon OS 3 V1R1', prefix: 'PHOS-03', based_on: srg)
    @p1_c1.reload

    # Create Users
    @p_admin = build(:user)
    @p_reviewer = build(:user)
    @p_author = build(:user)
    @other_p_admin = build(:user)

    # Give users project roles
    Membership.create(user: @p_admin, membership: @p1, role: 'admin')
    Membership.create(user: @p_reviewer, membership: @p1, role: 'reviewer')
    Membership.create(user: @p_author, membership: @p1, role: 'author')
    Membership.create(user: @other_p_admin, membership: @p2, role: 'admin')

    # Create rules
    @p1r1 = Rule.create(
      component: @p1_c1,
      rule_id: 'P1-R1',
      status: status_applicable,
      rule_severity: 'medium',
      srg_rule: srg.srg_rules.first
    )
  end

  # context 'overlaid rules are delegated to overlaid components' do
  #   it 'properly collects all rule information into one rule' do
  #     # Create a component overlay of `p2_c1 overlays p1_c1`
  #     @p2_c1 = Component.create(project: @p2, version: 'Photon OS 3.1 V1R1', prefix: 'PHOS-03')
  #     # Pick a rule to overlay
  #     rule_to_overlay = @p1_c1.rules.first
  #     # Create the overlaid version - connected via rule_id
  #     new_rule = Rule.create(component: @p2_c1, rule_id: rule_to_overlay.rule_id)
  #     # Verify that a field we will modify is currently nil
  #     expect(new_rule.status).to eq(nil)
  #     # Check that the field propagates through the overlay_rule method
  #     expect(new_rule.overlay_rule.status).not_to eq(nil)
  #     expect(new_rule.overlay_rule.status).to eq(rule_to_overlay.status)
  #     # Verify that the new_rule has no checks or disa descriptions
  #     expect(new_rule.checks.size).to eq(0)
  #     expect(new_rule.disa_rule_descriptions.size).to eq(0)
  #     # Verify that the overlaid rule has the right number of checks and disa descriptions
  #     expect(new_rule.overlay_rule.checks.size).not_to eq(0)
  #     expect(new_rule.overlay_rule.disa_rule_descriptions.size).not_to eq(0)
  #     expect(new_rule.overlay_rule.checks.size).to eq(rule_to_overlay.checks.size)
  #     expect(new_rule.overlay_rule.disa_rule_descriptions.size).to eq(rule_to_overlay.disa_rule_descriptions.size)
  #     # Add a check that is not an overlay on another check
  #     Check.create(rule: new_rule, content: 'not an overlay check')
  #     expect(new_rule.overlay_rule.checks.size).to eq(rule_to_overlay.checks.size + 1)
  #     # Add a check that is an overlay on another check
  #     check_to_overlay = rule_to_overlay.checks.first
  #     Check.create(rule: new_rule, content: 'an overlay check', check: check_to_overlay)
  #     expect(new_rule.overlay_rule.checks.size).to eq(rule_to_overlay.checks.size + 1)
  #     # Make sure that the check text was overridden
  #     expect(new_rule.overlay_rule.checks.select { |c| c.check_id == check_to_overlay.id }).to eq('an overlay check')
  #   end
  # end

  context 'rule duplication' do
    it 'properly duplicated rule and required associated records' do
      original_rule = @p1.rules.first

      # Clear any pre-existing associated records from SRG import
      original_rule.checks.destroy_all
      original_rule.rule_descriptions.destroy_all
      original_rule.disa_rule_descriptions.destroy_all

      # Add some checks
      Check.create(
        base_rule: original_rule,
        system: 'this is a test',
        content_ref_name: 'this is a test',
        content_ref_href: 'this is a test',
        content: 'this is a test'
      )
      Check.create(
        base_rule: original_rule,
        system: 'this is a test',
        content_ref_name: 'this is a test',
        content_ref_href: 'this is a test',
        content: 'this is a test'
      )
      # Add some descriptions
      DisaRuleDescription.create(
        base_rule: original_rule,
        vuln_discussion: 'this is a test',
        false_positives: 'this is a test',
        false_negatives: 'this is a test',
        documentable: true,
        mitigations: 'this is a test',
        severity_override_guidance: 'this is a test',
        potential_impacts: 'this is a test',
        third_party_tools: 'this is a test',
        mitigation_control: 'this is a test',
        responsibility: 'this is a test',
        ia_controls: 'this is a test'
      )
      DisaRuleDescription.create(
        base_rule: original_rule,
        vuln_discussion: 'this is a test',
        false_positives: 'this is a test',
        false_negatives: 'this is a test',
        documentable: true,
        mitigations: 'this is a test',
        severity_override_guidance: 'this is a test',
        potential_impacts: 'this is a test',
        third_party_tools: 'this is a test',
        mitigation_control: 'this is a test',
        responsibility: 'this is a test',
        ia_controls: 'this is a test'
      )
      RuleDescription.create(base_rule: original_rule, description: 'this is a test')

      # Add some reviews
      Review.create(rule: original_rule, user: @p_admin, action: 'request_review', comment: '...')
      Review.create(rule: original_rule, user: @p_admin, action: 'revoke_review_request', comment: '...')
      Review.create(rule: original_rule, user: @p_admin, action: 'comment', comment: '...')
      Review.create(rule: original_rule, user: @p_admin, action: 'request_review', comment: '...')
      Review.create(rule: original_rule, user: @p_admin, action: 'approve', comment: '...')
      Review.create(rule: original_rule, user: @p_admin, action: 'unlock_control', comment: '...')

      [
        { review_requestor_id: @p_admin.id, locked: false },
        { review_requestor_id: nil, locked: true }
      ].each do |original_rule_update_attributes|
        original_rule.update(original_rule_update_attributes)
        original_rule.reload
        new_rule = original_rule.amoeba_dup
        new_rule.rule_id = nil
        new_rule.save
        new_rule.reload

        # Expect all fields on the rule except id, locked, review_requestor_id, updated_at, created_at to be the same
        # Expect locked=false and review_requestor_id=nil
        # Expect rule_id to be changed because of uniqueness constraint
        rejectable_attrs = %w[id rule_id locked review_requestor_id updated_at created_at inspec_control_file]
        original_rule_attributes = original_rule.attributes.reject do |a|
          rejectable_attrs.include? a
        end
        new_rule_attributes = new_rule.attributes.reject do |a|
          rejectable_attrs.include? a
        end
        new_rule_attributes.each do |attribute, value|
          expect(value).to eq(original_rule_attributes[attribute])
        end
        expect(new_rule.review_requestor_id).to be_nil
        expect(new_rule.locked).to be(false)

        rejectable_attrs = %w[id base_rule_id updated_at created_at]
        # Expect all check fields on the rule except id, rule_id, updated_at, created_at to be the same
        expect(new_rule.checks.size).to eq(original_rule.checks.size)
        new_rule.checks.each_with_index do |new_check, index|
          original_check_attributes = original_rule.checks[index].attributes.reject do |a|
            rejectable_attrs.include? a
          end
          new_check_attributes = new_check.attributes.reject { |a| rejectable_attrs.include? a }
          new_check_attributes.each do |attribute, value|
            expect(value).to eq(original_check_attributes[attribute])
          end
        end

        # Expect all description fields on the rule except id, rule_id, updated_at, created_at to be the same
        expect(new_rule.rule_descriptions.size).to eq(original_rule.rule_descriptions.size)
        new_rule.rule_descriptions.each_with_index do |new_description, index|
          original_description_attributes = original_rule.rule_descriptions[index].attributes.reject do |a|
            rejectable_attrs.include? a
          end
          new_description_attributes = new_description.attributes.reject do |a|
            rejectable_attrs.include? a
          end
          new_description_attributes.each do |attribute, value|
            expect(value).to eq(original_description_attributes[attribute])
          end
        end

        # Expect all DISA description fields on the rule except id, rule_id, updated_at, created_at to be the same
        expect(new_rule.disa_rule_descriptions.size).to eq(original_rule.disa_rule_descriptions.size)
        new_rule.disa_rule_descriptions.each_with_index do |new_description, index|
          original_description_attributes = original_rule.disa_rule_descriptions[index].attributes.reject do |a|
            rejectable_attrs.include? a
          end
          new_description_attributes = new_description.attributes.reject do |a|
            rejectable_attrs.include? a
          end
          new_description_attributes.each do |attribute, value|
            expect(value).to eq(original_description_attributes[attribute])
          end
        end

        # Expect no audits, reviews to be empty on the new record
        expect(new_rule.audits.where.not(action: 'create').size).to eq(0)
        expect(new_rule.reviews.size).to eq(0)
      end
    end
  end

  context 'custom validations' do
    it 'properly validates cannot_be_locked_and_under_review' do
      expect(@p1r1.valid?).to be(true)

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.locked = false
      expect(@p1r1.save).to be(true)

      @p1r1.review_requestor_id = nil
      @p1r1.locked = true
      expect(@p1r1.save).to be(true)

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.locked = true
      expect(@p1r1.save).to be(false)
      expect(@p1r1.errors[:base]).to include('Control cannot be under review and locked at the same time.')
    end

    it 'properly validates prevent_destroy_if_under_review_or_locked when under review' do
      @p1r1.update(review_requestor_id: @p_admin.id)
      @p1r1.reload
      @p1r1.destroy
      expect(@p1r1.errors[:base]).to include('Control is under review and cannot be destroyed')
    end

    it 'properly validates prevent_destroy_if_under_review_or_locked when under locked' do
      @p1r1.update(locked: true)
      @p1r1.reload
      @p1r1.destroy
      expect(@p1r1.errors[:base]).to include('Control is locked and cannot be destroyed')
      expect(Rule.find_by(id: @p1r1.id)).not_to be_nil
    end

    it 'properly validates review_fields_cannot_change_with_other_fields' do
      @p1r1.review_requestor_id = @p_admin.id
      expect(@p1r1.valid?).to be(true)
      @p1r1.reload

      @p1r1.locked = true
      expect(@p1r1.valid?).to be(true)
      @p1r1.reload

      @p1r1.status_justification = '...'
      expect(@p1r1.valid?).to be(true)
      @p1r1.reload

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.status_justification = '...'
      expect(@p1r1.valid?).to be(false)
      expect(@p1r1.errors[:base]).to include(
        'Cannot update review-related attributes with other non-review-related attributes'
      )
      @p1r1.reload
    end
  end

  context 'rule with multiple ident' do
    it 'has a unique string list of cci sorted in ascending order' do
      @p1r1.ident = 'CCI-000068, CCI-000054, CCI-000054'
      @p1r1.save!
      expect(@p1r1.ident).to eq('CCI-000054, CCI-000068')
    end
  end

  context 'as_json satisfaction serialization' do
    # REQUIREMENT: Satisfaction relationships must include srg_id so the frontend
    # can display SRG requirement IDs (e.g., "SRG-OS-000480") for satisfied rules.
    # The srg_id field must be consistent with the parent rule's srg_id field.

    before do
      # Get a different SRG rule from the same SRG
      srg = SecurityRequirementsGuide.find(@p1_c1.security_requirements_guide_id)
      second_srg_rule = srg.srg_rules.where.not(id: @p1r1.srg_rule_id).first

      # Create a second rule with a different SRG rule
      @p1r2 = Rule.create!(
        component: @p1_c1,
        rule_id: 'P1-R2',
        status: status_applicable,
        rule_severity: 'high',
        srg_rule: second_srg_rule
      )
      # Create satisfaction: @p1r1 satisfies @p1r2
      @p1r1.satisfies << @p1r2
    end

    it 'includes srg_id in the satisfies array' do
      json = @p1r1.as_json
      satisfies_list = json[:satisfies]
      expect(satisfies_list).to be_an(Array)
      expect(satisfies_list.size).to eq(1)

      satisfied = satisfies_list.first
      expect(satisfied[:id]).to eq(@p1r2.id)
      expect(satisfied[:rule_id]).to eq('P1-R2')
      expect(satisfied[:srg_id]).to eq(@p1r2.srg_rule.version)
    end

    it 'includes srg_id in the satisfied_by array' do
      @p1r2.reload
      json = @p1r2.as_json
      satisfied_by_list = json[:satisfied_by]
      expect(satisfied_by_list).to be_an(Array)
      expect(satisfied_by_list.size).to eq(1)

      satisfier = satisfied_by_list.first
      expect(satisfier[:id]).to eq(@p1r1.id)
      expect(satisfier[:rule_id]).to eq('P1-R1')
      expect(satisfier[:srg_id]).to eq(@p1r1.srg_rule.version)
    end

    it 'overrides the DB srg_id column with srg_rule.version using string key' do
      json = @p1r1.as_json
      # Must be a string key to properly override super's string key from ActiveRecord
      expect(json).to have_key('srg_id')
      expect(json['srg_id']).to eq(@p1r1.srg_rule.version)
      # Symbol key should NOT also exist (would cause dual-key bug)
      expect(json).not_to have_key(:srg_id)
    end

    it 'handles satisfaction with nil srg_rule gracefully' do
      # belongs_to :srg_rule is required, so build (not create) to test edge case
      rule_no_srg = Rule.new(
        component: @p1_c1,
        rule_id: 'NO-SRG-002',
        status: status_applicable,
        rule_severity: 'medium',
        srg_rule: nil
      )
      # Verify as_json handles nil srg_rule in map without error
      json = rule_no_srg.as_json
      expect(json['srg_id']).to be_nil
      expect(json[:satisfies]).to eq([])
    end
  end

  context 'satisfaction_text (DRY satisfaction text generation)' do
    # REQUIREMENT: ONE method generates satisfaction text for all consumers.
    # Format: full SRG IDs, sorted, deduplicated.
    # Used by: XCCDF export (VulnDiscussion), CSV export (separate column), InSpec (tag).

    before do
      srg = SecurityRequirementsGuide.find(@p1_c1.security_requirements_guide_id)
      second_srg_rule = srg.srg_rules.where.not(id: @p1r1.srg_rule_id).first
      third_srg_rule = srg.srg_rules.where.not(id: [@p1r1.srg_rule_id, second_srg_rule.id]).first

      @p1r2 = Rule.create!(
        component: @p1_c1, rule_id: 'P1-R2',
        status: status_applicable, rule_severity: 'high',
        srg_rule: second_srg_rule
      )
      @p1r3 = Rule.create!(
        component: @p1_c1, rule_id: 'P1-R3',
        status: status_applicable, rule_severity: 'medium',
        srg_rule: third_srg_rule
      )
      # @p1r1 satisfies both @p1r2 and @p1r3
      @p1r1.satisfies << @p1r2
      @p1r1.satisfies << @p1r3
    end

    it 'generates SRG-format satisfaction text with full sorted IDs' do
      text = @p1r1.satisfaction_text(format: :srg, direction: :satisfies)
      expect(text).to start_with('Satisfies: ')
      ids = text.sub('Satisfies: ', '').split(', ')
      expect(ids.size).to eq(2)
      # Full SRG IDs (e.g., "SRG-OS-000004-GPOS-00004")
      expect(ids).to all(match(/^SRG-/))
      # Sorted alphabetically
      expect(ids).to eq(ids.sort)
    end

    it 'generates STIG-format satisfaction text with component prefix' do
      text = @p1r1.satisfaction_text(format: :stig, direction: :satisfies)
      expect(text).to start_with('Satisfies: ')
      ids = text.sub('Satisfies: ', '').split(', ')
      expect(ids.size).to eq(2)
      expect(ids).to all(start_with('PHOS-03-'))
      expect(ids).to eq(ids.sort)
    end

    it 'generates Satisfied By text for the inverse direction' do
      @p1r2.reload
      text = @p1r2.satisfaction_text(format: :srg, direction: :satisfied_by)
      expect(text).to start_with('Satisfied By: ')
      expect(text).to include(@p1r1.srg_rule.version)
    end

    it 'returns nil when no relationships exist' do
      # @p1r3 has no satisfies of its own (only satisfied_by)
      rule_no_rels = Rule.create!(
        component: @p1_c1, rule_id: 'P1-LONE',
        status: status_applicable, rule_severity: 'low',
        srg_rule: @p1r1.srg_rule
      )
      expect(rule_no_rels.satisfaction_text(format: :srg, direction: :satisfies)).to be_nil
    end

    it 'deduplicates IDs' do
      # Adding same rule twice should not create duplicate text
      # HABTM has unique index so this tests the text output
      text = @p1r1.satisfaction_text(format: :srg, direction: :satisfies)
      ids = text.sub('Satisfies: ', '').split(', ')
      expect(ids).to eq(ids.uniq)
    end
  end

  context 'export_vendor_comments (clean vendor comments for export)' do
    # REQUIREMENT: Vendor comments in exports contain ONLY user-authored text
    # plus dynamically generated satisfaction text. Never duplicates.

    before do
      srg = SecurityRequirementsGuide.find(@p1_c1.security_requirements_guide_id)
      second_srg_rule = srg.srg_rules.where.not(id: @p1r1.srg_rule_id).first

      @p1r2 = Rule.create!(
        component: @p1_c1, rule_id: 'P1-R2',
        status: status_applicable, rule_severity: 'high',
        srg_rule: second_srg_rule
      )
      @p1r1.satisfies << @p1r2
    end

    it 'includes user-authored vendor comments' do
      @p1r1.update!(vendor_comments: 'User wrote this comment.')
      text = @p1r1.export_vendor_comments
      expect(text).to include('User wrote this comment.')
    end

    it 'strips stale satisfaction text from raw vendor_comments' do
      @p1r1.update!(vendor_comments: 'User comment. Satisfies: CNTR-00-001234, CNTR-00-001235.')
      text = @p1r1.export_vendor_comments
      # Should NOT contain the old stale satisfaction text
      expect(text).not_to include('CNTR-00-001234')
      # Should contain the fresh dynamically generated satisfaction
      expect(text).to include('Satisfies: ')
      expect(text).to include('User comment')
    end

    it 'generates exactly one Satisfies line' do
      @p1r1.update!(vendor_comments: 'Some comment. Satisfies: OLD-001. Satisfied By: OLD-002.')
      text = @p1r1.export_vendor_comments
      expect(text.scan('Satisfies:').count).to eq(1)
    end

    it 'returns empty string when no comments and no relationships' do
      rule_clean = Rule.create!(
        component: @p1_c1, rule_id: 'CLEAN-R1',
        status: status_applicable, rule_severity: 'low',
        srg_rule: @p1r1.srg_rule
      )
      expect(rule_clean.export_vendor_comments).to eq('')
    end
  end

  context 'as_json with missing SRG data' do
    it 'handles rule with nil srg_rule gracefully' do
      # Create a rule without an srg_rule
      rule_without_srg = Rule.create(
        component: @p1_c1,
        rule_id: 'NO-SRG-001',
        status: status_applicable,
        rule_severity: 'medium',
        srg_rule: nil
      )
      # Should not raise an error
      json = nil
      expect { json = rule_without_srg.as_json }.not_to raise_error
      expect(json[:srg_rule_attributes]).to be_nil
      expect(json[:srg_info][:version]).to be_nil
    end

    it 'handles rule with srg_rule but nil security_requirements_guide_id' do
      # Create an SRG rule without a security_requirements_guide_id
      orphan_srg_rule = SrgRule.create(
        version: 'SRG-TEST-001',
        title: 'Test SRG Rule',
        security_requirements_guide_id: nil
      )
      rule_with_orphan_srg = Rule.create(
        component: @p1_c1,
        rule_id: 'ORPHAN-SRG-001',
        status: status_applicable,
        rule_severity: 'medium',
        srg_rule: orphan_srg_rule
      )
      # Should not raise an error
      json = nil
      expect { json = rule_with_orphan_srg.as_json }.not_to raise_error
      expect(json[:srg_info][:version]).to be_nil
    end

    it 'returns correct SRG version when all data is present' do
      # Use the existing @p1r1 which has a valid srg_rule
      json = @p1r1.as_json
      expect(json[:srg_info][:version]).not_to be_nil
      srg = @p1r1.srg_rule.security_requirements_guide
      expect(json[:srg_info][:version]).to eq(srg.version)
    end
  end
end
