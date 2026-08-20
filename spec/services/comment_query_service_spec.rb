# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommentQueryService do
  before { Rails.application.reload_routes! }

  let(:project) { create(:project) }
  let(:srg) { create(:security_requirements_guide) }
  let(:component) { create(:component, project: project, based_on: srg) }
  let(:rule) { component.rules.first }
  let(:commenter) { create(:user) }

  let!(:comment) do
    create(:review, :comment,
           rule: rule,
           user: commenter,
           comment: 'Test comment for filtering')
  end

  describe '.call' do
    it 'returns hash with rows, pagination, and status_counts keys' do
      result = described_class.new(component, {}).call
      expect(result.keys).to match_array(%i[rows pagination status_counts])
    end

    it 'includes satisfied_by parents in rule_content for child rules' do
      parent = component.rules.second
      rule.satisfied_by << parent

      result = described_class.new(component, { include_rule_content: true }).call

      content = result[:rows].first['rule_content']
      expect(content[:satisfied_by]).to eq(
        [{ id: parent.id, rule_id: parent.rule_id, component_prefix: component.prefix }]
      )
    end

    it 'serializes an empty satisfied_by for standalone rules' do
      result = described_class.new(component, { include_rule_content: true }).call
      expect(result[:rows].first['rule_content'][:satisfied_by]).to eq([])
    end

    it 'handles component-level comments through the rule-content preload path' do
      create(:review, :component_comment, commentable: component, commentable_type: 'Component',
                                          user: commenter, comment: 'Component-level note')

      result = described_class.new(component, { include_rule_content: true }).call

      component_row = result[:rows].find { |r| r['commentable_type'] == 'Component' }
      expect(component_row).to be_present
      expect(component_row['rule_content']).to be_nil
    end

    it 'returns the comment in rows' do
      result = described_class.new(component, {}).call
      expect(result[:rows].length).to eq(1)
      expect(result[:rows].first['id']).to eq(comment.id)
      expect(result[:rows].first['comment']).to eq('Test comment for filtering')
    end

    it 'returns correct pagination structure' do
      result = described_class.new(component, {}).call
      expect(result[:pagination]).to include(page: 1, per_page: 25, total: 1)
      expect(result[:pagination]).to have_key(:total_comments)
    end

    it 'filters by triage_status' do
      comment.update!(triage_status: 'concur')
      result = described_class.new(component, { triage_status: 'concur' }).call
      expect(result[:rows].length).to eq(1)

      result = described_class.new(component, { triage_status: 'non_concur' }).call
      expect(result[:rows].length).to eq(0)
    end

    it 'defaults the triage filter to pending at every layer — the one ruled default' do
      # The triage endpoints power the triage table, whose ruled default is
      # pending. The controller, this service, and both paginated_comments
      # entry points must agree — a layer defaulting to "all" here silently
      # widens any future caller that omits the param.
      comment.update!(triage_status: 'concur')
      pending_comment = create(:review, :comment, rule: rule, user: commenter,
                                                  comment: 'Still pending')

      {
        'CommentQueryService' => described_class.new(component, {}).call,
        'Component#paginated_comments' => component.paginated_comments,
        'Project#paginated_comments' => project.paginated_comments
      }.each do |layer, result|
        expect(result[:rows].map { |r| r['id'] }).to eq([pending_comment.id]),
                                                     "#{layer} did not default to pending"
      end
    end

    it 'filters by rule_id' do
      other_rule = component.rules.second
      create(:review, :comment, commentable: other_rule, user: commenter)

      result = described_class.new(component, { rule_id: rule.id }).call
      expect(result[:rows].length).to eq(1)
      expect(result[:rows].first['rule_id']).to eq(rule.id)
    end

    it 'filters by text query with ILIKE' do
      result = described_class.new(component, { query: 'filtering' }).call
      expect(result[:rows].length).to eq(1)

      result = described_class.new(component, { query: 'nonexistent' }).call
      expect(result[:rows].length).to eq(0)
    end

    it 'paginates results' do
      result = described_class.new(component, { page: 1, per_page: 1 }).call
      expect(result[:pagination][:per_page]).to eq(1)
    end

    it 'returns status_counts from unfiltered base scope' do
      comment.update!(triage_status: 'concur')
      result = described_class.new(component, {}).call
      expect(result[:status_counts]).to include('concur' => 1)
    end

    it 'produces identical output to Component#paginated_comments' do
      direct = component.paginated_comments
      via_service = described_class.new(component, {}).call
      expect(via_service[:rows].map { |r| r['id'] }).to eq(direct[:rows].map { |r| r['id'] }) # rubocop:disable Rails/Pluck
      expect(via_service[:pagination][:total]).to eq(direct[:pagination][:total])
      expect(via_service[:status_counts]).to eq(direct[:status_counts])
    end
  end
end
