# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review, type: :model do
  before :each do
    srg_xml = file_fixture('U_Web_Server_V2R3_Manual-xccdf.xml').read
    parsed_benchmark = Xccdf::Benchmark.parse(srg_xml)
    srg = SecurityRequirementsGuide.from_mapping(parsed_benchmark)
    srg.xml = srg_xml
    srg.save!
    # Create projects
    @p1 = Project.create(name: 'P1', prefix: 'AAAA-00', based_on: srg)
    @p2 = Project.create(name: 'P2', prefix: 'BBBB-00', based_on: srg)

    # Create Users
    @p_admin = build(:user)
    @p_reviewer = build(:user)
    @p_author = build(:user)
    @other_p_admin = build(:user)

    # Give users project roles
    ProjectMember.create!(user: @p_admin, project: @p1, role: 'admin')
    ProjectMember.create!(user: @p_reviewer, project: @p1, role: 'reviewer')
    ProjectMember.create!(user: @p_author, project: @p1, role: 'author')
    ProjectMember.create!(user: @other_p_admin, project: @p2, role: 'admin')

    # Create rules
    @p1r1 = Rule.create!(
      project: @p1,
      rule_id: 'P1-R1',
      status: 'Applicable - Configurable',
      rule_severity: 'medium'
    )
  end

  context 'rule duplication' do
    it 'properly duplicated rule and required associated records' do
      original_rule = @p1.rules.first

      # Add some checks
      Check.create(
        rule: original_rule,
        system: 'this is a test',
        content_ref_name: 'this is a test',
        content_ref_href: 'this is a test',
        content: 'this is a test'
      )
      Check.create(
        rule: original_rule,
        system: 'this is a test',
        content_ref_name: 'this is a test',
        content_ref_href: 'this is a test',
        content: 'this is a test'
      )
      # Add some descriptions
      DisaRuleDescription.create(
        rule: original_rule,
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
        rule: original_rule,
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
      RuleDescription.create(rule: original_rule, description: 'this is a test')

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
        # Normally we would epect rule_id to be set outside of amoeba_dup (e.g., in a controller)
        new_rule.rule_id = SecureRandom.hex(3)
        new_rule.save
        new_rule.reload

        # Expect all fields on the rule except id, locked, review_requestor_id, updated_at, created_at to be the same
        # Expect locked=false and review_requestor_id=nil
        # Expect rule_id to be changed because of uniqueness constraint
        rejectable_attrs = %w[id rule_id locked review_requestor_id updated_at created_at]
        original_rule_attributes = original_rule.attributes.reject do |a|
          rejectable_attrs.include? a
        end
        new_rule_attributes = new_rule.attributes.reject do |a|
          rejectable_attrs.include? a
        end
        new_rule_attributes.each do |attribute, value|
          expect(value).to eq(original_rule_attributes[attribute])
        end
        expect(new_rule.review_requestor_id).to eq(nil)
        expect(new_rule.locked).to eq(false)

        rejectable_attrs = %w[id rule_id updated_at created_at]
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
      expect(@p1r1.valid?).to eq(true)

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.locked = false
      expect(@p1r1.save).to eq(true)

      @p1r1.review_requestor_id = nil
      @p1r1.locked = true
      expect(@p1r1.save).to eq(true)

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.locked = true
      expect(@p1r1.save).to eq(false)
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
      expect(Rule.find_by(id: @p1r1.id)).to_not eq(nil)
    end

    it 'properly validates review_fields_cannot_change_with_other_fields' do
      @p1r1.review_requestor_id = @p_admin.id
      expect(@p1r1.valid?).to eq(true)
      @p1r1.reload

      @p1r1.locked = true
      expect(@p1r1.valid?).to eq(true)
      @p1r1.reload

      @p1r1.status_justification = '...'
      expect(@p1r1.valid?).to eq(true)
      @p1r1.reload

      @p1r1.review_requestor_id = @p_admin.id
      @p1r1.status_justification = '...'
      expect(@p1r1.valid?).to eq(false)
      expect(@p1r1.errors[:base]).to include(
        'Cannot update review-related attributes with other non-review-related attributes'
      )
      @p1r1.reload
    end
  end
end
