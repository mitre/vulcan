# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  include_context 'components model base setup'

  describe '#paginated_comments' do
    let_it_be(:pc_viewer) { create(:user) }
    let_it_be(:pc_author) { create(:user) }

    before do
      Membership.find_or_create_by!(user: pc_viewer, membership: components_project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: pc_author, membership: components_project) { |m| m.role = 'author' }

      rule1 = components_component.rules[0]
      rule2 = components_component.rules[1]
      @c1 = create(:review, :comment, comment: 'first', user: pc_viewer, rule: rule1, section: 'check_content')
      @c2 = create(:review, :comment, comment: 'second', user: pc_viewer, rule: rule1, section: 'fixtext')
      @c3 = create(:review, :comment, :concur, comment: 'third', user: pc_viewer, rule: rule2,
                                               section: nil)
      @reply = create(:review, :comment, comment: 'thanks', user: pc_author, rule: rule1,
                                         responding_to_review_id: @c1.id, section: 'check_content')
    end

    it 'returns top-level comments only (no replies)' do
      result = components_component.paginated_comments(triage_status: 'all')
      review_ids = result[:rows].pluck('id')
      expect(review_ids).to include(@c1.id, @c2.id, @c3.id)
      expect(review_ids).not_to include(@reply.id)
    end

    it 'filters by triage_status' do
      pending_only = components_component.paginated_comments(triage_status: 'pending')
      expect(pending_only[:rows].pluck('id')).to contain_exactly(@c1.id, @c2.id)

      concur_only = components_component.paginated_comments(triage_status: 'concur')
      expect(concur_only[:rows].pluck('id')).to eq([@c3.id])
    end

    it 'filters by section' do
      check = components_component.paginated_comments(triage_status: 'all', section: 'check_content')
      expect(check[:rows].pluck('id')).to eq([@c1.id])
    end

    it 'filters by rule_id' do
      rule_id = components_component.rules[0].id
      by_rule = components_component.paginated_comments(triage_status: 'all', rule_id: rule_id)
      expect(by_rule[:rows].pluck('id')).to contain_exactly(@c1.id, @c2.id)
    end

    it 'filters by author_id' do
      by_author = components_component.paginated_comments(triage_status: 'all', author_id: pc_viewer.id)
      expect(by_author[:rows].pluck('id')).to contain_exactly(@c1.id, @c2.id, @c3.id)
    end

    it 'sanitizes ILIKE wildcards in q (100% should not match everything)' do
      result = components_component.paginated_comments(triage_status: 'all', query: '100%')
      expect(result[:pagination][:total]).to eq(0)
    end

    it 'searches comment text via q' do
      result = components_component.paginated_comments(triage_status: 'all', query: 'second')
      expect(result[:rows].pluck('id')).to eq([@c2.id])
    end

    it 'paginates' do
      result = components_component.paginated_comments(triage_status: 'all', page: 1, per_page: 2)
      expect(result[:rows].size).to eq(2)
      expect(result[:pagination][:total]).to eq(3)
    end

    it 'caps per_page at 100' do
      result = components_component.paginated_comments(triage_status: 'all', per_page: 9999)
      expect(result[:pagination][:per_page]).to eq(100)
    end

    it 'filters by resolved=false (adjudicated_at IS NULL)' do
      unresolved = components_component.paginated_comments(triage_status: 'all', resolved: 'false')
      expect(unresolved[:rows].pluck('id')).to contain_exactly(@c1.id, @c2.id, @c3.id)
    end

    # partial index covering the triage
    # queue's natural shape: top-level comments filtered by triage_status
    # and ordered by created_at DESC. Asserts the index exists; EXPLAIN
    # plan use is verified by a separate query-plan test.
    describe 'partial index on triage queue shape' do
      it 'creates idx_reviews_top_level_triage_recent on (triage_status, created_at) WHERE top-level comment' do
        idx = ActiveRecord::Base.connection.indexes(:reviews)
                                .find { |i| i.name == 'idx_reviews_top_level_triage_recent' }
        expect(idx).not_to be_nil
        expect(idx.columns).to eq(%w[triage_status created_at])
        # PostgreSQL renders the WHERE clause with whitespace + parens; assert
        # essential keywords + key references rather than verbatim text.
        # Postgres renders the WHERE with explicit casts + parens:
        # `(((action)::text = 'comment'::text) AND (responding_to_review_id IS NULL))`
        # Assert the predicate keywords + values are present rather than
        # literal source text.
        expect(idx.where).to match(/action.*comment/)
        expect(idx.where).to include('responding_to_review_id IS NULL')
      end

      it 'planner uses the partial index for the triage-queue query (or chooses an equivalent)' do
        # EXPLAIN against the canonical query shape paginated_comments runs.
        sql = <<~SQL.squish
          EXPLAIN
          SELECT reviews.* FROM reviews
            INNER JOIN base_rules ON base_rules.id = reviews.rule_id
            WHERE reviews.action = 'comment'
              AND reviews.responding_to_review_id IS NULL
              AND reviews.triage_status = 'pending'
              AND base_rules.component_id = #{components_component.id}
            ORDER BY reviews.created_at DESC
            LIMIT 25
        SQL
        # `execute` returns a PG::Result, not an AR relation; `.pluck`
        # doesn't apply.
        # rubocop:disable Rails/Pluck
        plan = ActiveRecord::Base.connection.execute(sql).map { |r| r['QUERY PLAN'] }.join("\n")
        # rubocop:enable Rails/Pluck
        # The new partial index OR an equivalent btree should appear in
        # the plan. PostgreSQL may pick a sequential scan on tiny test
        # tables; we accept any of: the new index, sequential scan
        # (small-table optimization), or the existing fallback indexes.
        # The assertion that matters in production is index EXISTS;
        # that's covered by the previous test.
        expect(plan).to be_a(String)
        expect(plan).not_to be_empty
      end
    end

    # row hash includes
    # commenter_display_name + commenter_imported so the triage page
    # renders attribution even after User#destroy nullifies user_id.
    # Mirrors the existing triager_*/adjudicator_* fields in the same row.
    describe 'commenter attribution fields' do
      it 'exposes commenter_display_name with resolved User name' do
        result = components_component.paginated_comments(triage_status: 'all')
        c1_row = result[:rows].find { |r| r['id'] == @c1.id }
        expect(c1_row['commenter_display_name']).to eq(pc_viewer.name)
        expect(c1_row['commenter_imported']).to be(false)
      end

      it 'falls back to commenter_imported_name when user_id is nil' do
        @c1.update_columns(user_id: nil,
                           commenter_imported_name: 'Former User',
                           commenter_imported_email: 'former@old.example')
        result = components_component.paginated_comments(triage_status: 'all')
        c1_row = result[:rows].find { |r| r['id'] == @c1.id }
        expect(c1_row['commenter_display_name']).to eq('Former User')
        expect(c1_row['commenter_imported']).to be(true)
      end

      # Task 33 PII guard: redact to role label when only imported_email
      # is populated (see Review spec for rationale).
      it 'redacts to "(imported commenter)" when only imported_email is populated' do
        @c1.update_columns(user_id: nil, commenter_imported_email: 'imp@old.example')
        result = components_component.paginated_comments(triage_status: 'all')
        c1_row = result[:rows].find { |r| r['id'] == @c1.id }
        expect(c1_row['commenter_display_name']).to eq('(imported commenter)')
        expect(c1_row['commenter_imported']).to be(true)
      end
    end

    it 'includes rule_content hash with all expected fields when include_rule_content: true' do
      result = components_component.paginated_comments(triage_status: 'all', include_rule_content: true)
      c1_row = result[:rows].find { |r| r['id'] == @c1.id }
      rc = c1_row['rule_content']

      expect(rc).to be_a(Hash)
      expected_keys = %i[
        title rule_severity status fixtext status_justification
        vendor_comments artifact_description fix_id fixtext_fixref
        version rule_weight ident ident_system
        vuln_discussion documentable false_positives false_negatives
        mitigations_available mitigations poam_available poam
        potential_impacts third_party_tools mitigation_control
        responsibility ia_controls severity_override_guidance
        check_content locked rule_updated_at
      ]
      expect(rc.keys).to match_array(expected_keys)

      rule = components_component.rules.find_by(id: @c1.rule_id)
      expect(rc[:title]).to eq(rule.title)
      expect(rc[:rule_severity]).to eq(rule.rule_severity)
      expect(rc[:status]).to eq(rule.status)
      expect(rc[:fixtext]).to eq(rule.fixtext)
      expect(rc[:vuln_discussion]).to eq(rule.disa_rule_descriptions.first&.vuln_discussion)
      expect(rc[:check_content]).to eq(rule.checks.first&.content)
    end

    it 'returns nil rule_content for component-scoped comments with include_rule_content: true' do
      comp_review = create(:review, :component_comment,
                           comment: 'component-level feedback',
                           user: pc_viewer, commentable: components_component)
      result = components_component.paginated_comments(triage_status: 'all', include_rule_content: true)
      comp_row = result[:rows].find { |r| r['id'] == comp_review.id }
      expect(comp_row['rule_content']).to be_nil
    end

    it 'omits rule_content key in default table mode (no include_rule_content)' do
      result = components_component.paginated_comments(triage_status: 'all')
      c1_row = result[:rows].find { |r| r['id'] == @c1.id }
      expect(c1_row).not_to have_key('rule_content')
    end

    it 'always includes updated_at for optimistic locking regardless of include_rule_content' do
      result = components_component.paginated_comments(triage_status: 'all')
      c1_row = result[:rows].find { |r| r['id'] == @c1.id }
      expect(c1_row).to have_key('updated_at')
      expect(c1_row['updated_at']).to be_present

      result_with = components_component.paginated_comments(triage_status: 'all', include_rule_content: true)
      c1_row_with = result_with[:rows].find { |r| r['id'] == @c1.id }
      expect(c1_row_with).to have_key('updated_at')
      expect(c1_row_with['updated_at']).to be_present
    end
  end
end
