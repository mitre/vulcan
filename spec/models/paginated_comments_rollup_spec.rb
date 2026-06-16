# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'paginated_comments — parent rollup fields' do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project, based_on: srg) }

  let_it_be(:parent_rule) { component.rules.find_by(rule_id: component.rules.pluck(:rule_id).min) }
  let_it_be(:child_rule) { component.rules.where.not(id: parent_rule.id).first }

  before_all do
    RuleSatisfaction.find_or_create_by!(rule_id: child_rule.id, satisfied_by_rule_id: parent_rule.id)
  end

  let_it_be(:parent_comment) do
    create(:review, :comment, rule: parent_rule, comment: 'Comment on parent')
  end

  let_it_be(:child_comment) do
    user = create(:user)
    Review.insert!({
                     action: 'comment', comment: 'Comment on child',
                     rule_id: child_rule.id, commentable_type: 'BaseRule',
                     commentable_id: child_rule.id, user_id: user.id,
                     created_at: Time.current, updated_at: Time.current
                   })
    Review.order(created_at: :desc).first
  end

  describe 'Component#paginated_comments' do
    it 'includes parent_rule_displayed_name for child rule comments' do
      result = component.paginated_comments(triage_status: 'all', per_page: 50)
      child_row = result[:rows].find { |r| r['id'] == child_comment.id }
      expect(child_row).not_to be_nil
      expect(child_row['parent_rule_displayed_name']).to eq("#{component.prefix}-#{parent_rule.rule_id}")
    end

    it 'returns nil parent_rule_displayed_name for parent/standalone rule comments' do
      result = component.paginated_comments(triage_status: 'all', per_page: 50)
      parent_row = result[:rows].find { |r| r['id'] == parent_comment.id }
      expect(parent_row).not_to be_nil
      expect(parent_row).to have_key('parent_rule_displayed_name')
      expect(parent_row['parent_rule_displayed_name']).to be_nil
    end

    it 'includes group_rule_displayed_name that resolves to parent for children' do
      result = component.paginated_comments(triage_status: 'all', per_page: 50)
      child_row = result[:rows].find { |r| r['id'] == child_comment.id }
      parent_name = "#{component.prefix}-#{parent_rule.rule_id}"
      expect(child_row['group_rule_displayed_name']).to eq(parent_name)
    end

    it 'includes group_rule_displayed_name that is own name for standalone comments' do
      result = component.paginated_comments(triage_status: 'all', per_page: 50)
      parent_row = result[:rows].find { |r| r['id'] == parent_comment.id }
      expect(parent_row['group_rule_displayed_name']).to eq(parent_row['rule_displayed_name'])
    end
  end
end
