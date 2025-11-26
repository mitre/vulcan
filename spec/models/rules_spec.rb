# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review, type: :model do
  before do
    srg_xml = file_fixture('U_GPOS_SRG_V2R1_Manual-xccdf.xml').read
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
      status: 'Applicable - Configurable',
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

  context 'satisfied_by relationship and status' do
    it 'preserves parent status when adding satisfied_by relationship' do
      # Use existing rules from the component
      parent_rule = @p1_c1.rules[0]
      child_rule = @p1_c1.rules[1]

      # Store original database status
      original_db_status = parent_rule[:status]

      # Set parent to Applicable - Configurable
      parent_rule.update!(status: 'Applicable - Configurable')
      parent_rule.reload
      expect(parent_rule.status).to eq('Applicable - Configurable')
      expect(parent_rule[:status]).to eq('Applicable - Configurable')

      # Add child to parent's satisfied_by list
      parent_rule.satisfied_by << child_rule
      child_rule.save! # Trigger callbacks as per controller
      parent_rule.reload

      # Status getter should return Applicable - Configurable
      expect(parent_rule.status).to eq('Applicable - Configurable')
      # Database status should still be Applicable - Configurable, not reset
      expect(parent_rule[:status]).to eq('Applicable - Configurable')
      expect(parent_rule[:status]).not_to eq(original_db_status) unless original_db_status == 'Applicable - Configurable'
    end

    it 'automatically sets status to Applicable - Configurable when satisfied_by exists' do
      parent_rule = @p1_c1.rules[2]
      child_rule = @p1_c1.rules[3]

      # Add satisfied_by relationship
      parent_rule.satisfied_by << child_rule
      child_rule.save!
      parent_rule.reload

      # Status getter should return Applicable - Configurable regardless of stored value
      expect(parent_rule.status).to eq('Applicable - Configurable')
    end

    it 'prevents status changes when satisfied_by exists' do
      parent_rule = @p1_c1.rules[4]
      child_rule = @p1_c1.rules[5]

      # Add satisfied_by relationship
      parent_rule.satisfied_by << child_rule
      child_rule.save!
      parent_rule.reload
      expect(parent_rule.status).to eq('Applicable - Configurable')

      # Try to change status - should be prevented by setter
      parent_rule.status = 'Not Applicable'
      parent_rule.save!
      parent_rule.reload

      # Status should still be Applicable - Configurable (via getter)
      expect(parent_rule.status).to eq('Applicable - Configurable')
    end
  end
end
