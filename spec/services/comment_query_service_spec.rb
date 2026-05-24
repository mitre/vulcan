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

    it 'returns the comment in rows' do
      result = described_class.new(component, {}).call
      expect(result[:rows].length).to eq(1)
      expect(result[:rows].first[:id]).to eq(comment.id)
      expect(result[:rows].first[:comment]).to eq('Test comment for filtering')
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

    it 'filters by rule_id' do
      other_rule = component.rules.second
      create(:review, :comment, commentable: other_rule, user: commenter)

      result = described_class.new(component, { rule_id: rule.id }).call
      expect(result[:rows].length).to eq(1)
      expect(result[:rows].first[:rule_id]).to eq(rule.id)
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
      expect(via_service[:rows].map { |r| r[:id] }).to eq(direct[:rows].map { |r| r[:id] }) # rubocop:disable Rails/Pluck
      expect(via_service[:pagination][:total]).to eq(direct[:pagination][:total])
      expect(via_service[:status_counts]).to eq(direct[:status_counts])
    end
  end
end
