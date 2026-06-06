# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review do
  include_context 'reviews model base setup'

  # snapshot serialization for
  # the admin_destroy Component-level audit row. Captures full pre-
  # destroy state (full comment, every audited + lifecycle column,
  # ISO8601 timestamps so YAML safe-load doesn't break on Audit#find).
  describe '#snapshot_attributes' do
    let!(:snap_review) do
      create(:review, :comment, comment: 'snap content', user: reviews_p_viewer, rule: reviews_rule,
                                section: 'check_content',
                                triage_status: 'concur',
                                triage_set_by_id: reviews_p_admin.id,
                                triage_set_at: Time.zone.parse('2026-04-01T10:00:00Z'),
                                adjudicated_at: Time.zone.parse('2026-04-02T11:00:00Z'),
                                adjudicated_by_id: reviews_p_admin.id)
    end

    it 'returns a hash with every audited + lifecycle + imported_attribution column' do
      h = snap_review.snapshot_attributes
      %w[id user_id rule_id action comment section triage_status
         triage_set_by_id triage_set_at adjudicated_at adjudicated_by_id
         duplicate_of_review_id responding_to_review_id
         triage_set_by_imported_email triage_set_by_imported_name
         adjudicated_by_imported_email adjudicated_by_imported_name
         commenter_imported_email commenter_imported_name
         created_at updated_at].each do |col|
        expect(h).to have_key(col)
      end
    end

    it 'preserves the FULL comment text (not truncated)' do
      long = 'x' * 3000
      snap_review.update!(comment: long)
      expect(snap_review.snapshot_attributes['comment']).to eq(long)
    end

    it 'serializes timestamps as ISO8601 strings (not Time objects)' do
      h = snap_review.snapshot_attributes
      expect(h['triage_set_at']).to be_a(String)
      expect(h['triage_set_at']).to match(/\AZ?\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      expect(h['adjudicated_at']).to be_a(String)
      expect(h['created_at']).to be_a(String)
      expect(h['updated_at']).to be_a(String)
    end

    it 'returns nil for unset nullable fields, not empty strings' do
      bare = create(:review, :comment, comment: 'bare', section: nil, user: reviews_p_viewer, rule: reviews_rule)
      h = bare.snapshot_attributes
      expect(h['triage_set_by_id']).to be_nil
      expect(h['adjudicated_at']).to be_nil
      expect(h['triage_set_by_imported_email']).to be_nil
    end
  end

  # SQL CTE scope for the
  # snapshot-capture step in admin_destroy. Returns root + every
  # descendant via responding_to_review_id chain, in deterministic
  # depth-first-ish order so the audit-row snapshot is reproducible.
  describe '.subtree_with_ancestry' do
    let!(:root) do
      create(:review, :comment, comment: 'root', section: nil, user: reviews_p_viewer, rule: reviews_rule)
    end
    let!(:child_a) do
      create(:review, :comment, comment: 'child A', section: nil, user: reviews_p_viewer, rule: reviews_rule,
                                responding_to_review_id: root.id)
    end
    let!(:child_b) do
      create(:review, :comment, comment: 'child B', section: nil, user: reviews_p_viewer, rule: reviews_rule,
                                responding_to_review_id: root.id)
    end
    let!(:grandchild) do
      create(:review, :comment, comment: 'grandchild of A', section: nil, user: reviews_p_viewer, rule: reviews_rule,
                                responding_to_review_id: child_a.id)
    end

    it 'returns the root and every descendant' do
      ids = Review.subtree_with_ancestry(root.id).map(&:id)
      expect(ids).to contain_exactly(root.id, child_a.id, child_b.id, grandchild.id)
    end

    it 'returns just the root when there are no replies' do
      lone = create(:review, :comment, comment: 'lone', section: nil, user: reviews_p_viewer, rule: reviews_rule)
      expect(Review.subtree_with_ancestry(lone.id).map(&:id)).to eq([lone.id])
    end

    it 'returns deterministic order: root first, then by parent_id NULLS FIRST, created_at' do
      ids = Review.subtree_with_ancestry(root.id).map(&:id)
      # root is first (parent_id is nil within the subtree-as-roots framing)
      expect(ids.first).to eq(root.id)
      # grandchild MUST come after its parent child_a (depth ordering)
      expect(ids.index(grandchild.id)).to be > ids.index(child_a.id)
    end

    it 'returns nothing when the root id does not exist' do
      expect(Review.subtree_with_ancestry(0)).to be_empty
    end

    it 'is an ActiveRecord::Relation of Review records (not raw rows)' do
      result = Review.subtree_with_ancestry(root.id)
      expect(result.first).to be_a(Review)
      # Has access to associations, not just attributes
      expect(result.first.user).to eq(reviews_p_viewer)
    end
  end
end
