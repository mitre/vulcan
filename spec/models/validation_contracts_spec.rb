# frozen_string_literal: true

require 'rails_helper'

# =============================================================================
# MODEL VALIDATION CONTRACTS
# =============================================================================
#
# This spec documents and enforces the minimum initialization requirements for
# every core domain model. Each model must validate its required fields and
# associations to prevent null-reference crashes and data integrity issues.
#
# Pattern: shoulda-matchers one-liners for simple validations/associations,
# behavioral tests for models with complex callbacks or custom validators.
# Following Discourse/GitLab/Mastodon conventions.
#
# Models with complex associations use factory-built subjects so
# shoulda-matchers can test validations against valid base records.
# =============================================================================

REQUIRED_FIELD_VALIDATIONS = 'required field validations'
UNIQUENESS_CONSTRAINTS = 'uniqueness constraints'

RSpec.describe 'Model validation contracts' do
  # Shared setup: SRG + Project used by Component, Rule, and Review tests.
  # Created once per example group that needs them.
  let(:srg) { create(:security_requirements_guide) }
  let(:project) { create(:project) }
  let(:component) { create(:component, project: project, based_on: srg) }

  # ===========================================================================
  # COMPONENT
  # ===========================================================================
  #
  # Components are STIG-ready security guidance documents. They belong to a
  # Project and are based on an SRG. Every component MUST have a name, prefix,
  # and title — these are used in sorting, display, and export filenames.
  #
  # The NewComponentModal form requires name (line 383), prefix (line 124),
  # and title (line 132). The backend MUST match frontend requirements.
  # ===========================================================================
  describe Component do
    subject { build(:component) }

    describe REQUIRED_FIELD_VALIDATIONS do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:prefix) }
      it { is_expected.to validate_presence_of(:title) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:project).inverse_of(:components) }
      it { is_expected.to belong_to(:based_on).class_name('SecurityRequirementsGuide') }
      it { is_expected.to belong_to(:component).class_name('Component').optional }
      it { is_expected.to have_many(:rules).dependent(:destroy) }
      it { is_expected.to have_many(:child_components).class_name('Component').dependent(:destroy) }
      it { is_expected.to have_many(:memberships) }
      it { is_expected.to have_many(:users).through(:memberships) }
      it { is_expected.to have_one(:component_metadata).dependent(:destroy) }
      it { is_expected.to have_many(:additional_questions).dependent(:destroy) }
    end
  end

  # ===========================================================================
  # PROJECT
  # ===========================================================================
  describe Project do
    describe REQUIRED_FIELD_VALIDATIONS do
      it { is_expected.to validate_presence_of(:name) }
    end

    describe 'associations' do
      it { is_expected.to have_many(:components).dependent(:destroy) }
      it { is_expected.to have_many(:memberships) }
      it { is_expected.to have_many(:users).through(:memberships) }
    end
  end

  # ===========================================================================
  # USER
  # ===========================================================================
  describe User do
    describe REQUIRED_FIELD_VALIDATIONS do
      it { is_expected.to validate_presence_of(:name) }
    end
  end

  # ===========================================================================
  # SECURITY REQUIREMENTS GUIDE (SRG)
  # ===========================================================================
  describe SecurityRequirementsGuide do
    describe REQUIRED_FIELD_VALIDATIONS do
      it { is_expected.to validate_presence_of(:srg_id) }
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_presence_of(:version) }
      it { is_expected.to validate_presence_of(:xml) }
    end

    describe UNIQUENESS_CONSTRAINTS do
      subject { create(:security_requirements_guide) }

      it { is_expected.to validate_uniqueness_of(:srg_id).scoped_to(:version).with_message(' ID has already been taken') }
    end

    describe 'associations' do
      it { is_expected.to have_many(:srg_rules).dependent(:destroy) }
      it { is_expected.to have_many(:components) }
    end
  end

  # ===========================================================================
  # STIG
  # ===========================================================================
  describe Stig do
    describe REQUIRED_FIELD_VALIDATIONS do
      it { is_expected.to validate_presence_of(:stig_id) }
      it { is_expected.to validate_presence_of(:title) }
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:version) }
      it { is_expected.to validate_presence_of(:xml) }
    end

    describe UNIQUENESS_CONSTRAINTS do
      subject { create(:stig) }

      it { is_expected.to validate_uniqueness_of(:stig_id).scoped_to(:version).with_message('ID has already been taken') }
    end

    describe 'associations' do
      it { is_expected.to have_many(:stig_rules).dependent(:destroy) }
    end
  end

  # ===========================================================================
  # RULE
  # ===========================================================================
  #
  # Rule has complex callbacks (before_validation :set_rule_id, before_save,
  # after_save :update_inspec_code) and custom validators that make shoulda
  # one-liners unreliable. Behavioral tests verify the actual REQUIREMENTS:
  #
  # - Every rule MUST have a rule_id (auto-generated if blank)
  # - rule_id must be unique within a component
  # - status must be one of the defined STATUSES
  # - severity must be one of the defined SEVERITIES
  # ===========================================================================
  describe Rule do
    subject(:rule_under_test) { component.reload.rules.first }

    describe 'rule_id contract' do
      it 'auto-generates rule_id when blank via before_validation callback' do
        new_rule = component.rules.build(srg_rule: rule_under_test.srg_rule)
        new_rule.rule_id = nil
        new_rule.valid?
        expect(new_rule.rule_id).to be_present
      end

      it 'preserves explicitly provided rule_id' do
        new_rule = component.rules.build(srg_rule: rule_under_test.srg_rule, rule_id: '999999')
        new_rule.valid?
        expect(new_rule.rule_id).to eq('999999')
      end

      it 'rejects duplicate rule_id within the same component' do
        duplicate = component.rules.build(srg_rule: rule_under_test.srg_rule, rule_id: rule_under_test.rule_id)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:rule_id]).to be_present
      end
    end

    describe 'status contract' do
      it 'rejects invalid status values' do
        rule_under_test.status = 'Invalid Status'
        expect(rule_under_test).not_to be_valid
        expect(rule_under_test.errors[:status]).to be_present
      end

      it 'accepts all defined statuses' do
        RuleConstants::STATUSES.each do |status|
          rule_under_test.status = status
          rule_under_test.valid?
          expect(rule_under_test.errors[:status]).to be_empty, "Expected '#{status}' to be a valid status"
        end
      end
    end

    describe 'severity contract' do
      it 'rejects invalid severity values' do
        rule_under_test.rule_severity = 'critical'
        expect(rule_under_test).not_to be_valid
        expect(rule_under_test.errors[:rule_severity]).to be_present
      end

      it 'accepts all defined severities' do
        RuleConstants::SEVERITIES.each do |severity|
          rule_under_test.rule_severity = severity
          rule_under_test.valid?
          expect(rule_under_test.errors[:rule_severity]).to be_empty, "Expected '#{severity}' to be a valid severity"
        end
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:component) }
      it { is_expected.to belong_to(:srg_rule) }
      it { is_expected.to belong_to(:review_requestor).class_name('User').optional }
      it { is_expected.to have_many(:reviews).dependent(:destroy) }
      it { is_expected.to have_many(:additional_answers).dependent(:destroy) }
    end
  end

  # ===========================================================================
  # REVIEW
  # ===========================================================================
  #
  # Review has custom validators (validate_project_permissions, can_approve,
  # etc.) that access user and rule associations. These validators now include
  # nil guards so they produce clean validation errors instead of NoMethodError.
  # ===========================================================================
  describe Review do
    subject(:review) do
      review_user = create(:user)
      review_rule = component.reload.rules.first
      Membership.create!(user: review_user, membership: component.project, role: 'admin')
      Review.new(user: review_user, rule: review_rule, comment: 'Test', action: 'comment')
    end

    describe REQUIRED_FIELD_VALIDATIONS do
      it { is_expected.to validate_presence_of(:comment) }
      it { is_expected.to validate_presence_of(:action) }
    end

    describe 'required associations' do
      it 'requires a user' do
        review.user = nil
        expect(review).not_to be_valid
        expect(review.errors[:user]).to be_present
      end

      it 'requires a rule' do
        review.rule = nil
        expect(review).not_to be_valid
        expect(review.errors[:rule]).to be_present
      end
    end
  end

  # ===========================================================================
  # MEMBERSHIP
  # ===========================================================================
  #
  # Membership is polymorphic (belongs_to :membership can be Project or
  # Component). It has a custom validator that accesses the polymorphic
  # association, so nil guards are required. Behavioral tests verify the
  # role inclusion contract.
  # ===========================================================================
  describe Membership do
    subject(:membership_record) { Membership.new(user: create(:user), membership: project, role: 'viewer') }

    describe 'role contract' do
      it 'rejects invalid roles' do
        membership_record.role = 'superadmin'
        expect(membership_record).not_to be_valid
        expect(membership_record.errors[:role]).to be_present
      end

      it 'accepts all defined project member roles' do
        Membership::PROJECT_MEMBER_ROLES.each do |role|
          membership_record.role = role
          membership_record.valid?
          expect(membership_record.errors[:role]).to be_empty, "Expected '#{role}' to be a valid role"
        end
      end
    end

    describe 'required associations' do
      it 'requires a user' do
        membership_record.user = nil
        expect(membership_record).not_to be_valid
      end

      it 'requires a membership target (project or component)' do
        membership_record.membership = nil
        expect(membership_record).not_to be_valid
      end
    end
  end

  # ===========================================================================
  # PROJECT ACCESS REQUEST
  # ===========================================================================
  describe ProjectAccessRequest do
    describe UNIQUENESS_CONSTRAINTS do
      it 'prevents duplicate access requests for same user and project' do
        existing = create(:project_access_request)
        duplicate = ProjectAccessRequest.new(user: existing.user, project: existing.project)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_id]).to be_present
      end

      it 'allows same user to request access to different projects' do
        existing = create(:project_access_request)
        new_request = ProjectAccessRequest.new(user: existing.user, project: create(:project))
        expect(new_request).to be_valid
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:user) }
      it { is_expected.to belong_to(:project) }
    end
  end

  # ===========================================================================
  # COMPONENT METADATA
  # ===========================================================================
  describe ComponentMetadata do
    describe 'associations' do
      it { is_expected.to belong_to(:component) }
    end
  end

  # ===========================================================================
  # ADDITIONAL QUESTION
  # ===========================================================================
  describe AdditionalQuestion do
    describe REQUIRED_FIELD_VALIDATIONS do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_presence_of(:question_type) }
    end

    describe UNIQUENESS_CONSTRAINTS do
      subject do
        c = create(:component)
        AdditionalQuestion.create!(name: 'Test Q', question_type: 'freeform', component: c)
      end

      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:component_id) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:component) }
      it { is_expected.to have_many(:additional_answers).dependent(:destroy) }
    end
  end

  # ===========================================================================
  # ADDITIONAL ANSWER
  # ===========================================================================
  describe AdditionalAnswer do
    subject do
      c = create(:component)
      rule = c.reload.rules.first
      q = AdditionalQuestion.create!(name: 'Test Q', question_type: 'freeform', component: c)
      AdditionalAnswer.new(rule: rule, additional_question: q)
    end

    describe 'associations' do
      it { is_expected.to belong_to(:additional_question) }
      it { is_expected.to belong_to(:rule) }
    end
  end
end
