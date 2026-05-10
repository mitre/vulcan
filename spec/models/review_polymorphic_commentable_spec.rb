# frozen_string_literal: true

require 'rails_helper'

# Polymorphic Review (issue #725): a Review can target either a Rule
# (existing behavior, dual-written via the sync_commentable_from_rule
# callback) or a Component (new component-level comments). Rule is STI
# under BaseRule, so AR's polymorphic_name default writes 'BaseRule' for
# rule-scoped reviews; we keep that for consistency with the audit table's
# associated_type column on existing rule audits.
RSpec.describe 'Polymorphic Review.commentable' do
  let_it_be(:project) { create(:project) }
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:component) { create(:component, project: project, based_on: srg, comment_phase: 'open') }
  let_it_be(:user) { create(:user) }

  let(:rule) { component.rules.first }

  describe 'commentable polymorphism' do
    it 'stores commentable_type=BaseRule (STI base class) when targeting a Rule via the dual-write callback' do
      r = Review.create!(rule: rule, user: user, action: 'comment', comment: 'rule-scoped')
      expect(r.commentable_type).to eq('BaseRule')
      expect(r.commentable_id).to eq(rule.id)
    end

    it 'stores commentable_type=Component when targeting a Component directly' do
      r = Review.create!(commentable: component, user: user, action: 'comment', comment: 'component-scoped')
      expect(r.commentable_type).to eq('Component')
      expect(r.commentable_id).to eq(component.id)
      expect(r.rule_id).to be_nil
    end
  end

  describe 'Component#paginated_comments union' do
    let!(:rule_comment) { Review.create!(rule: rule, user: user, action: 'comment', comment: 'rule comment') }
    let!(:component_comment) { Review.create!(commentable: component, user: user, action: 'comment', comment: 'component comment') }

    it 'returns BOTH rule-scoped and component-scoped top-level comments' do
      result = component.paginated_comments
      ids = result[:rows].pluck(:id)
      expect(ids).to include(rule_comment.id, component_comment.id)
      expect(result[:pagination][:total]).to eq(2)
    end

    it 'tags component-scoped rows with rule_displayed_name=(component) and rule_id=nil' do
      result = component.paginated_comments
      row = result[:rows].find { |r| r[:id] == component_comment.id }
      expect(row[:rule_displayed_name]).to eq('(component)')
      expect(row[:rule_id]).to be_nil
      expect(row[:commentable_type]).to eq('Component')
    end

    it 'rule_id filter narrows to the specific rule (excludes component-scoped rows)' do
      result = component.paginated_comments(rule_id: rule.id)
      ids = result[:rows].pluck(:id)
      expect(ids).to eq([rule_comment.id])
    end
  end

  describe 'Project#paginated_comments union' do
    let!(:rule_comment) { Review.create!(rule: rule, user: user, action: 'comment', comment: 'rc') }
    let!(:component_comment) { Review.create!(commentable: component, user: user, action: 'comment', comment: 'cc') }

    it 'aggregates rule-scoped and component-scoped reviews across the project' do
      result = project.paginated_comments
      ids = result[:rows].pluck(:id)
      expect(ids).to include(rule_comment.id, component_comment.id)
      expect(result[:pagination][:total]).to eq(2)
    end
  end

  describe 'Project aggregate counts' do
    let!(:rule_pending) { Review.create!(rule: rule, user: user, action: 'comment', comment: 'rp') }
    let!(:component_pending) { Review.create!(commentable: component, user: user, action: 'comment', comment: 'cp') }

    it 'pending_comment_counts includes both scopes' do
      counts = Project.pending_comment_counts([project.id])
      expect(counts[project.id]).to eq(2)
    end

    it 'comment_counts pending+total includes both scopes' do
      counts = Project.comment_counts([project.id])
      expect(counts[project.id]).to eq(pending: 2, total: 2)
    end
  end
end
