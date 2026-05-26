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

    it 'clamps per_page to 100 maximum' do
      result = described_class.new(component, { per_page: 500 }).call
      expect(result[:pagination][:per_page]).to eq(100)
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

    it 'total_comments counts all comments including replies' do
      create(:review, :comment, rule: rule, user: commenter, comment: 'reply',
                                responding_to_review_id: comment.id)
      result = described_class.new(component, {}).call
      expect(result[:pagination][:total]).to eq(1)
      expect(result[:pagination][:total_comments]).to eq(2)
    end

    it 'does not define count_total_comments (merged into build_all_comments_scope)' do
      service = described_class.new(component, {})
      expect(service.respond_to?(:count_total_comments, true)).to be(false)
    end

    it 'reuses rule_id_subquery across base and all-comments scopes' do
      service = described_class.new(component, {})
      subquery1 = service.send(:rule_id_subquery)
      subquery2 = service.send(:rule_id_subquery)
      expect(subquery1).to equal(subquery2)
    end

    it 'does not use send() to call private methods on other objects' do
      source = Rails.root.join('app/services/comment_query_service.rb').read
      expect(source).not_to include('send(:serialize_rule_content'),
                            'CQS should call serialize_rule_content directly, not via send()'
    end

    it 'uses subquery instead of .ids for RuleSatisfaction lookup' do
      ids_queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        next unless payload[:name] != 'SCHEMA'
        # Catch standalone .ids: starts with SELECT "base_rules"."id" FROM
        # Subqueries start with SELECT COUNT/SELECT "reviews" and contain the subquery inside IN(...)
        next unless sql.start_with?('SELECT "base_rules"."id" FROM')

        ids_queries << sql
      }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        described_class.new(component, {}).call
      end

      expect(ids_queries).to be_empty,
                             "serialize_rows should use subquery for RuleSatisfaction, not .ids:\n#{ids_queries.join("\n")}"
    end
  end
end
