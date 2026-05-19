# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Factory traits', type: :model do
  before do
    Rails.application.reload_routes!
  end

  # ── Rule factory traits ──

  describe 'Rule :locked' do
    it 'creates a locked rule' do
      rule = create(:rule, :locked)
      expect(rule.locked).to be(true)
    end
  end

  describe 'Rule :applicable_configurable' do
    it 'sets status to Applicable - Configurable' do
      rule = create(:rule, :applicable_configurable)
      expect(rule.status).to eq('Applicable - Configurable')
    end
  end

  describe 'Rule :not_applicable' do
    it 'sets status to Not Applicable' do
      rule = create(:rule, :not_applicable)
      expect(rule.status).to eq('Not Applicable')
    end
  end

  describe 'Rule :not_yet_determined' do
    it 'sets status to Not Yet Determined' do
      rule = create(:rule, :not_yet_determined)
      expect(rule.status).to eq('Not Yet Determined')
    end
  end

  # ── Project factory traits ──

  describe 'Project :with_admin' do
    it 'creates project with an admin membership' do
      project = create(:project, :with_admin)
      admin_memberships = project.memberships.where(role: 'admin')
      expect(admin_memberships.count).to eq(1)
    end

    it 'accepts a specific admin_user' do
      user = create(:user)
      project = create(:project, :with_admin, admin_user: user)
      expect(project.memberships.find_by(role: 'admin').user).to eq(user)
    end
  end

  describe 'Project :with_members' do
    it 'creates project with all 4 role tiers by default' do
      project = create(:project, :with_members)
      roles = project.memberships.pluck(:role).sort
      expect(roles).to eq(%w[admin author reviewer viewer])
    end
  end

  # ── Component factory traits ──

  describe 'Component :open_comment_period' do
    it 'sets comment_phase to open with date window' do
      component = create(:component, :skip_rules, :open_comment_period)
      expect(component.comment_phase).to eq('open')
      expect(component.comment_period_starts_at).to be < Time.current
      expect(component.comment_period_ends_at).to be > Time.current
    end
  end

  describe 'Component :with_poc' do
    it 'sets admin_name and admin_email' do
      component = create(:component, :skip_rules, :with_poc)
      expect(component.admin_name).to be_present
      expect(component.admin_email).to include('@')
    end
  end

  describe 'Component :released' do
    it 'sets released to true and locks rules' do
      component = create(:component, :released)
      expect(component.released).to be(true)
      expect(component.rules.where(locked: false).count).to eq(0)
    end
  end

  # ── Membership factory trait ──

  describe 'Membership :viewer' do
    it 'creates a viewer membership' do
      membership = create(:membership, :viewer)
      expect(membership.role).to eq('viewer')
    end
  end

  describe ':comment trait' do
    it 'creates a valid top-level comment with pending triage status' do
      review = create(:review, :comment)
      expect(review).to be_persisted
      expect(review.action).to eq('comment')
      expect(review.section).to eq('check_content')
      expect(review.triage_status).to eq('pending')
      expect(review.responding_to_review_id).to be_nil
    end
  end

  describe ':reply trait' do
    it 'creates a valid reply linked to a parent comment' do
      review = create(:review, :reply)
      expect(review).to be_persisted
      expect(review.action).to eq('comment')
      expect(review.responding_to_review_id).to be_present
      expect(review.triage_status).to be_nil
    end
  end

  describe ':component_comment trait' do
    it 'creates a comment on a component instead of a rule' do
      review = create(:review, :component_comment)
      expect(review).to be_persisted
      expect(review.commentable_type).to eq('Component')
      expect(review.rule_id).to be_nil
    end
  end

  describe 'triage status traits' do
    it ':concur sets triage_status and triager' do
      review = create(:review, :comment, :concur)
      expect(review.triage_status).to eq('concur')
      expect(review.triage_set_by_id).to be_present
      expect(review.triage_set_at).to be_present
    end

    it ':non_concur sets triage_status and triager' do
      review = create(:review, :comment, :non_concur)
      expect(review.triage_status).to eq('non_concur')
      expect(review.triage_set_by_id).to be_present
    end

    it ':concur_with_comment sets triage_status and triager' do
      review = create(:review, :comment, :concur_with_comment)
      expect(review.triage_status).to eq('concur_with_comment')
      expect(review.triage_set_by_id).to be_present
    end

    it ':informational sets terminal status and auto-adjudicates' do
      review = create(:review, :comment, :informational)
      expect(review.triage_status).to eq('informational')
      expect(review.adjudicated_at).to be_present
    end

    it ':withdrawn sets terminal status and auto-adjudicates' do
      review = create(:review, :comment, :withdrawn)
      expect(review.triage_status).to eq('withdrawn')
      expect(review.adjudicated_at).to be_present
    end

    it ':duplicate sets status with duplicate_of target' do
      review = create(:review, :comment, :duplicate)
      expect(review.triage_status).to eq('duplicate')
      expect(review.duplicate_of_review_id).to be_present
      expect(review.adjudicated_at).to be_present
    end

    it ':needs_clarification sets triage_status' do
      review = create(:review, :comment, :needs_clarification)
      expect(review.triage_status).to eq('needs_clarification')
      expect(review.triage_set_by_id).to be_present
    end
  end

  describe ':triaged trait' do
    it 'sets triage metadata on a comment' do
      review = create(:review, :comment, :triaged)
      expect(review.triage_set_by_id).to be_present
      expect(review.triage_set_at).to be_present
    end
  end

  describe ':adjudicated trait' do
    it 'sets adjudication metadata on a triaged comment' do
      review = create(:review, :comment, :concur, :adjudicated)
      expect(review.adjudicated_at).to be_present
      expect(review.adjudicated_by_id).to be_present
    end
  end
end
