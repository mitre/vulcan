# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  let(:status_applicable) { 'Applicable - Configurable' }
  let(:satisfies_prefix) { 'Satisfies: ' }

  include_context 'srg model base setup'

  context 'rule duplication' do
    it 'properly duplicated rule and required associated records' do
      original_rule = project.rules.first

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
      Review.create(rule: original_rule, user: p_admin, action: 'request_review', comment: '...')
      Review.create(rule: original_rule, user: p_admin, action: 'revoke_review_request', comment: '...')
      Review.create(rule: original_rule, user: p_admin, action: 'comment', comment: '...')
      Review.create(rule: original_rule, user: p_admin, action: 'request_review', comment: '...')
      Review.create(rule: original_rule, user: p_admin, action: 'approve', comment: '...')
      Review.create(rule: original_rule, user: p_admin, action: 'unlock_control', comment: '...')

      [
        { review_requestor_id: p_admin.id, locked: false },
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
      expect(rule.valid?).to be(true)

      rule.review_requestor_id = p_admin.id
      rule.locked = false
      expect(rule.save).to be(true)

      rule.review_requestor_id = nil
      rule.locked = true
      expect(rule.save).to be(true)

      rule.review_requestor_id = p_admin.id
      rule.locked = true
      expect(rule.save).to be(false)
      expect(rule.errors[:base]).to include('Control cannot be under review and locked at the same time.')
    end

    it 'properly validates prevent_destroy_if_under_review_or_locked when under review' do
      rule.update(review_requestor_id: p_admin.id)
      rule.reload
      rule.destroy
      expect(rule.errors[:base]).to include('Control is under review and cannot be destroyed')
    end

    it 'properly validates prevent_destroy_if_under_review_or_locked when under locked' do
      rule.update(locked: true)
      rule.reload
      rule.destroy
      expect(rule.errors[:base]).to include('Control is locked and cannot be destroyed')
      expect(Rule.find_by(id: rule.id)).not_to be_nil
    end

    it 'properly validates review_fields_cannot_change_with_other_fields' do
      rule.review_requestor_id = p_admin.id
      expect(rule.valid?).to be(true)
      rule.reload

      rule.locked = true
      expect(rule.valid?).to be(true)
      rule.reload

      rule.status_justification = '...'
      expect(rule.valid?).to be(true)
      rule.reload

      rule.review_requestor_id = p_admin.id
      rule.status_justification = '...'
      expect(rule.valid?).to be(false)
      expect(rule.errors[:base]).to include(
        'Cannot update review-related attributes with other non-review-related attributes'
      )
      rule.reload
    end
  end

  context 'rule with multiple ident' do
    it 'has a unique string list of cci sorted in ascending order' do
      rule.ident = 'CCI-000068, CCI-000054, CCI-000054'
      rule.save!
      expect(rule.ident).to eq('CCI-000054, CCI-000068')
    end
  end

  context 'RuleBlueprint satisfaction serialization' do
    # REQUIREMENT: Satisfaction relationships must include srg_id so the frontend
    # can display SRG requirement IDs (e.g., "SRG-OS-000480") for satisfied rules.
    # The srg_id field must be consistent with the parent rule's srg_id field.

    before do
      # Get a different SRG rule from the same SRG
      srg = SecurityRequirementsGuide.find(component.security_requirements_guide_id)
      second_srg_rule = srg.srg_rules.where.not(id: rule.srg_rule_id).first

      # Create a second rule with a different SRG rule
      @p1r2 = Rule.create!(
        component: component,
        rule_id: 'P1-R2',
        status: status_applicable,
        rule_severity: 'high',
        srg_rule: second_srg_rule
      )
      # Create satisfaction: rule satisfies @p1r2
      rule.satisfies << @p1r2
    end

    it 'includes srg_id in the satisfies array' do
      json = RuleBlueprint.render_as_json(rule, view: :editor)
      satisfies_list = json['satisfies']
      expect(satisfies_list).to be_an(Array)
      expect(satisfies_list.size).to eq(1)

      satisfied = satisfies_list.first
      expect(satisfied['id']).to eq(@p1r2.id)
      expect(satisfied['rule_id']).to eq('P1-R2')
      expect(satisfied['srg_id']).to eq(@p1r2.srg_rule.version)
    end

    it 'includes srg_id in the satisfied_by array' do
      @p1r2.reload
      json = RuleBlueprint.render_as_json(@p1r2, view: :editor)
      satisfied_by_list = json['satisfied_by']
      expect(satisfied_by_list).to be_an(Array)
      expect(satisfied_by_list.size).to eq(1)

      satisfier = satisfied_by_list.first
      expect(satisfier['id']).to eq(rule.id)
      expect(satisfier['rule_id']).to eq('P1-R1')
      expect(satisfier['srg_id']).to eq(rule.srg_rule.version)
    end

    it 'includes srg_id derived from srg_rule.version' do
      json = RuleBlueprint.render_as_json(rule, view: :editor)
      expect(json).to have_key('srg_id')
      expect(json['srg_id']).to eq(rule.srg_rule.version)
    end

    it 'does NOT include version in satisfaction objects (frontend uses srg_id)' do
      json = RuleBlueprint.render_as_json(rule, view: :editor)
      satisfies_list = json['satisfies']
      satisfied = satisfies_list.first

      # CRITICAL CONTRACT: Frontend RuleNavigator uses srg_id for display.
      # If version were included, it would mask the bug where template
      # references satisfies.version instead of satisfies.srg_id.
      expect(satisfied).to have_key('srg_id')
      expect(satisfied).not_to have_key('version')
      expect(satisfied.keys).to match_array(%w[id rule_id srg_id])
    end

    it 'does NOT include version in satisfied_by objects (frontend uses srg_id)' do
      @p1r2.reload
      json = RuleBlueprint.render_as_json(@p1r2, view: :editor)
      satisfied_by_list = json['satisfied_by']
      satisfier = satisfied_by_list.first

      expect(satisfier).to have_key('srg_id')
      expect(satisfier).not_to have_key('version')
      expect(satisfier.keys).to match_array(%w[id rule_id fixtext srg_id component_prefix])
    end

    it 'handles satisfaction with nil srg_rule gracefully' do
      # belongs_to :srg_rule is required, so build (not create) to test edge case
      rule_no_srg = Rule.new(
        component: component,
        rule_id: 'NO-SRG-002',
        status: status_applicable,
        rule_severity: 'medium',
        srg_rule: nil
      )
      # Verify blueprint handles nil srg_rule without error
      json = RuleBlueprint.render_as_json(rule_no_srg, view: :editor)
      expect(json['srg_id']).to be_nil
      expect(json['satisfies']).to eq([])
    end
  end

  context 'satisfaction_text (DRY satisfaction text generation)' do
    # REQUIREMENT: ONE method generates satisfaction text for all consumers.
    # Format: full SRG IDs, sorted, deduplicated.
    # Used by: XCCDF export (VulnDiscussion), CSV export (separate column), InSpec (tag).

    before do
      srg = SecurityRequirementsGuide.find(component.security_requirements_guide_id)
      second_srg_rule = srg.srg_rules.where.not(id: rule.srg_rule_id).first
      third_srg_rule = srg.srg_rules.where.not(id: [rule.srg_rule_id, second_srg_rule.id]).first

      @p1r2 = Rule.create!(
        component: component, rule_id: 'P1-R2',
        status: status_applicable, rule_severity: 'high',
        srg_rule: second_srg_rule
      )
      @p1r3 = Rule.create!(
        component: component, rule_id: 'P1-R3',
        status: status_applicable, rule_severity: 'medium',
        srg_rule: third_srg_rule
      )
      # rule satisfies both @p1r2 and @p1r3
      rule.satisfies << @p1r2
      rule.satisfies << @p1r3
    end

    it 'generates SRG-format satisfaction text with full sorted IDs' do
      text = rule.satisfaction_text(format: :srg, direction: :satisfies)
      expect(text).to start_with(satisfies_prefix)
      ids = text.sub(satisfies_prefix, '').split(', ')
      expect(ids.size).to eq(2)
      # Full SRG IDs (e.g., "SRG-OS-000004-GPOS-00004")
      expect(ids).to all(match(/^SRG-/))
      # Sorted alphabetically
      expect(ids).to eq(ids.sort)
    end

    it 'generates STIG-format satisfaction text with component prefix' do
      text = rule.satisfaction_text(format: :stig, direction: :satisfies)
      expect(text).to start_with(satisfies_prefix)
      ids = text.sub(satisfies_prefix, '').split(', ')
      expect(ids.size).to eq(2)
      expect(ids).to all(start_with('PHOS-03-'))
      expect(ids).to eq(ids.sort)
    end

    it 'generates Satisfied By text for the inverse direction' do
      @p1r2.reload
      text = @p1r2.satisfaction_text(format: :srg, direction: :satisfied_by)
      expect(text).to start_with('Satisfied By: ')
      expect(text).to include(rule.srg_rule.version)
    end

    it 'returns nil when no relationships exist' do
      # @p1r3 has no satisfies of its own (only satisfied_by)
      rule_no_rels = Rule.create!(
        component: component, rule_id: 'P1-LONE',
        status: status_applicable, rule_severity: 'low',
        srg_rule: rule.srg_rule
      )
      expect(rule_no_rels.satisfaction_text(format: :srg, direction: :satisfies)).to be_nil
    end

    it 'deduplicates IDs' do
      # Adding same rule twice should not create duplicate text
      # HABTM has unique index so this tests the text output
      text = rule.satisfaction_text(format: :srg, direction: :satisfies)
      ids = text.sub(satisfies_prefix, '').split(', ')
      expect(ids).to eq(ids.uniq)
    end
  end

  context 'export_vendor_comments (clean vendor comments for export)' do
    # REQUIREMENT: Vendor comments in exports contain ONLY user-authored text
    # plus dynamically generated satisfaction text. Never duplicates.

    before do
      srg = SecurityRequirementsGuide.find(component.security_requirements_guide_id)
      second_srg_rule = srg.srg_rules.where.not(id: rule.srg_rule_id).first

      @p1r2 = Rule.create!(
        component: component, rule_id: 'P1-R2',
        status: status_applicable, rule_severity: 'high',
        srg_rule: second_srg_rule
      )
      rule.satisfies << @p1r2
    end

    it 'includes user-authored vendor comments' do
      rule.update!(vendor_comments: 'User wrote this comment.')
      text = rule.export_vendor_comments
      expect(text).to include('User wrote this comment.')
    end

    it 'strips stale satisfaction text from raw vendor_comments' do
      rule.update!(vendor_comments: 'User comment. Satisfies: CNTR-00-001234, CNTR-00-001235.')
      text = rule.export_vendor_comments
      # Should NOT contain the old stale satisfaction text
      expect(text).not_to include('CNTR-00-001234')
      # Should contain the fresh dynamically generated satisfaction
      expect(text).to include(satisfies_prefix)
      expect(text).to include('User comment')
    end

    it 'generates exactly one Satisfies line' do
      rule.update!(vendor_comments: 'Some comment. Satisfies: OLD-001. Satisfied By: OLD-002.')
      text = rule.export_vendor_comments
      expect(text.scan('Satisfies:').count).to eq(1)
    end

    it 'returns empty string when no comments and no relationships' do
      rule_clean = Rule.create!(
        component: component, rule_id: 'CLEAN-R1',
        status: status_applicable, rule_severity: 'low',
        srg_rule: rule.srg_rule
      )
      expect(rule_clean.export_vendor_comments).to eq('')
    end
  end

  context 'RuleBlueprint with missing SRG data' do
    it 'handles rule with nil srg_rule gracefully' do
      rule_without_srg = Rule.create(
        component: component,
        rule_id: 'NO-SRG-001',
        status: status_applicable,
        rule_severity: 'medium',
        srg_rule: nil
      )
      json = nil
      expect { json = RuleBlueprint.render_as_json(rule_without_srg, view: :editor) }.not_to raise_error
      expect(json['srg_rule_attributes']).to be_nil
      expect(json['srg_info']['version']).to be_nil
    end

    it 'handles rule with srg_rule but nil security_requirements_guide_id' do
      orphan_srg_rule = SrgRule.create(
        version: 'SRG-TEST-001',
        title: 'Test SRG Rule',
        security_requirements_guide_id: nil
      )
      rule_with_orphan_srg = Rule.create(
        component: component,
        rule_id: 'ORPHAN-SRG-001',
        status: status_applicable,
        rule_severity: 'medium',
        srg_rule: orphan_srg_rule
      )
      json = nil
      expect { json = RuleBlueprint.render_as_json(rule_with_orphan_srg, view: :editor) }.not_to raise_error
      expect(json['srg_info']['version']).to be_nil
    end

    it 'returns correct SRG version when all data is present' do
      # Use the existing rule which has a valid srg_rule
      json = RuleBlueprint.render_as_json(rule, view: :editor)
      expect(json['srg_info']['version']).not_to be_nil
      srg = rule.srg_rule.security_requirements_guide
      expect(json['srg_info']['version']).to eq(srg.version)
    end
  end

  describe 'update_inspec_code (after_save callback)' do
    it 'regenerates inspec_control_file after title change' do
      rule.update!(title: 'Updated title for InSpec test', audit_comment: 'test')
      rule.reload
      expect(rule.inspec_control_file).to include('Updated title for InSpec test')
    end

    it 'regenerates inspec_control_file after fixtext change' do
      rule.update!(fixtext: 'New fix text content here', audit_comment: 'test')
      rule.reload
      expect(rule.inspec_control_file).to include('New fix text content here')
    end

    it 'uses update_column — no recursion guard needed' do
      rule.update!(title: 'No flag test', audit_comment: 'test')
      expect(rule).not_to respond_to(:skip_update_inspec_code)
    end

    it 'handles rule with no disa_rule_descriptions gracefully' do
      rule.disa_rule_descriptions.destroy_all
      rule.update!(title: 'No desc test', audit_comment: 'test')
      rule.reload
      expect(rule.inspec_control_file).to include('No desc test')
      expect(rule.inspec_control_file).not_to include('vuln_discussion')
    end

    it 'includes inspec_control_body when present' do
      rule.update!(
        inspec_control_body: "describe service('sshd') do\n  it { should be_running }\nend",
        audit_comment: 'test'
      )
      rule.reload
      expect(rule.inspec_control_file).to include("describe service('sshd')")
    end

    it 'update_column rolls back with the parent transaction on error' do
      rule.update!(title: 'Rollback test title', audit_comment: 'test')
      rule.reload
      new_file = rule.inspec_control_file
      expect(new_file).to include('Rollback test title')

      begin
        Rule.transaction do
          rule.update!(title: 'Should be rolled back', audit_comment: 'rollback')
          raise ActiveRecord::Rollback
        end
      rescue ActiveRecord::Rollback
        # expected
      end

      rule.reload
      expect(rule.title).to eq('Rollback test title')
      expect(rule.inspec_control_file).to eq(new_file)
    end

    it 'does not update updated_at (derived column — no false cache invalidation)' do
      rule.reload
      original_updated_at = rule.updated_at
      rule.update!(title: 'Timestamp check', audit_comment: 'test')
      rule.reload
      expect(rule.updated_at).to be > original_updated_at
      saved_updated_at = rule.updated_at

      rule.update_inspec_code
      rule.reload
      expect(rule.updated_at).to eq(saved_updated_at)
    end
  end

  describe 'status getter/setter — no custom override (regression guard)' do
    let(:parent_rule) { component.rules.second }
    let(:child_rule) { rule }

    before do
      child_rule.satisfied_by << parent_rule unless child_rule.satisfied_by.include?(parent_rule)
    end

    after do
      child_rule.satisfied_by.delete(parent_rule)
    end

    it 'status returns the actual DB value for a child with satisfied_by' do
      expect(child_rule.satisfied_by.size).to be > 0

      child_rule.update!(status: 'Applicable - Does Not Meet', audit_comment: 'regression')
      child_rule.reload

      expect(child_rule.status).to eq('Applicable - Does Not Meet')
      expect(child_rule[:status]).to eq(child_rule.status)
    end

    it 'status= persists on child rules (setter is not a no-op)' do
      expect(child_rule.satisfied_by.size).to be > 0

      child_rule.status = 'Not Applicable'
      child_rule.audit_comment = 'regression'
      child_rule.save!
      child_rule.reload

      expect(child_rule.status).to eq('Not Applicable')
    end

    it 'apply_nesting_status! sets ADNM and reads back correctly' do
      child_rule.apply_nesting_status!(parent_rule)
      child_rule.reload

      expect(child_rule.status).to eq('Applicable - Does Not Meet')
      expect(child_rule[:status]).to eq('Applicable - Does Not Meet')
    end

    it 'fixtext returns the child own text, not the parent (export_fixtext delegates)' do
      child_rule.update!(fixtext: 'Child-specific fix text', audit_comment: 'regression')
      parent_rule.update!(fixtext: 'Parent fix text', audit_comment: 'regression')
      child_rule.reload

      expect(child_rule.fixtext).to eq('Child-specific fix text')
      expect(child_rule.send(:export_fixtext)).to eq('Parent fix text')
      expect(child_rule.fixtext).not_to eq(child_rule.send(:export_fixtext))
    end
  end
end
