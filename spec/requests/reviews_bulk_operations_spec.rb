# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews request base setup'

  describe 'soft redirect — comments on satisfied-by children' do
    let_it_be(:viewer) { create(:user) }
    let(:parent_rule) { component.rules.first }
    let(:child_rule) { component.rules.second }

    before do
      create(:membership, user: viewer, membership: project, role: 'viewer')
      child_rule.satisfied_by << parent_rule
      sign_in viewer
    end

    it 'redirects comment to parent rule when child is satisfied-by' do
      post "/rules/#{child_rule.id}/reviews",
           params: { action: 'comment', comment: 'This check is vendor-specific', section: 'fixtext' },
           as: :json

      expect(response).to have_http_status(:ok)
      review = Review.last
      expect(review.rule_id).to eq(parent_rule.id)
      expect(review.commentable_id).to eq(parent_rule.id)
    end

    it 'sets original_commentable_id to the child rule' do
      post "/rules/#{child_rule.id}/reviews",
           params: { action: 'comment', comment: 'Vendor concern', section: 'fixtext' },
           as: :json

      review = Review.last
      expect(review.original_commentable_id).to eq(child_rule.id)
    end

    it 'prefixes comment with [Re: prefix-child_rule_id]' do
      post "/rules/#{child_rule.id}/reviews",
           params: { action: 'comment', comment: 'Vendor concern', section: 'fixtext' },
           as: :json

      review = Review.last
      expect(review.comment).to start_with("[Re: #{component.prefix}-#{child_rule.rule_id}]")
      expect(review.comment).to include('Vendor concern')
    end

    it 'does NOT redirect when rule has no satisfied-by parent' do
      standalone = component.rules.where.not(id: [parent_rule.id, child_rule.id]).first
      post "/rules/#{standalone.id}/reviews",
           params: { action: 'comment', comment: 'Normal comment', section: 'fixtext' },
           as: :json

      expect(response).to have_http_status(:ok)
      review = Review.last
      expect(review.rule_id).to eq(standalone.id)
      expect(review.original_commentable_id).to be_nil
      expect(review.comment).to eq('Normal comment')
    end
  end

  describe 'PATCH /reviews/bulk_triage' do
    let_it_be(:bulk_triager) { create(:user) }
    let_it_be(:bulk_commenter) { create(:user) }
    let_it_be(:bulk_other_project) { create(:project) }
    let_it_be(:bulk_other_component) { create(:component, project: bulk_other_project, based_on: srg) }

    before_all do
      Membership.find_or_create_by!(user: bulk_triager, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: bulk_commenter, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: bulk_commenter, membership: bulk_other_project) { |m| m.role = 'viewer' }
    end

    let(:rule_a) { component.rules.first }
    let(:rule_b) { component.rules.second }
    let!(:comment_a) do
      create(:review, :comment, comment: 'logging not applicable', user: bulk_commenter,
                                rule: rule_a, section: 'check_content')
    end
    let!(:comment_b) do
      create(:review, :comment, comment: 'logging not applicable too', user: bulk_commenter,
                                rule: rule_b, section: 'fixtext')
    end

    context 'as an author' do
      before { sign_in bulk_triager }

      it 'applies triage status to all selected reviews in one request' do
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'informational',
          response_comment: 'Acknowledged — no change required.'
        }, as: :json

        expect(response).to have_http_status(:ok)

        [comment_a, comment_b].each do |c|
          c.reload
          expect(c.triage_status).to eq('informational')
          expect(c.triage_set_by_id).to eq(bulk_triager.id)
          expect(c.triage_set_at).to be_within(5.seconds).of(Time.current)
        end
      end

      it 'creates one self-contained response comment per original (not shared)' do
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'concur_with_comment',
          response_comment: 'Adopting with a stricter regex.'
        }, as: :json

        expect(response).to have_http_status(:ok)
        responses = Review.where(responding_to_review_id: [comment_a.id, comment_b.id])
        expect(responses.count).to eq(2)
        expect(responses.pluck(:responding_to_review_id)).to contain_exactly(comment_a.id, comment_b.id)
        expect(responses.map(&:comment).uniq).to eq(['Adopting with a stricter regex.'])
        expect(responses.map(&:user_id).uniq).to eq([bulk_triager.id])
      end

      it 'rejects bulk triage spanning multiple components' do
        foreign = create(:review, :comment, comment: 'other component concern',
                                            user: bulk_commenter, rule: bulk_other_component.rules.first,
                                            section: nil)
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, foreign.id],
          triage_status: 'informational'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(comment_a.reload.triage_status).to eq('pending')
        expect(foreign.reload.triage_status).to eq('pending')
      end
    end

    context 'as a project viewer' do
      let_it_be(:bulk_viewer) { create(:user) }

      before do
        Membership.find_or_create_by!(user: bulk_viewer, membership: project) { |m| m.role = 'viewer' }
        sign_in bulk_viewer
      end

      it 'forbids bulk triage' do
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'informational'
        }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(comment_a.reload.triage_status).to eq('pending')
      end
    end
  end

  describe 'PATCH /reviews/merge' do
    let_it_be(:merge_admin) { create(:user) }
    let_it_be(:merge_author) { create(:user) }
    let_it_be(:merge_commenter) { create(:user) }
    let_it_be(:merge_other_commenter) { create(:user) }
    let_it_be(:merge_other_project) { create(:project) }
    let_it_be(:merge_other_component) { create(:component, project: merge_other_project, based_on: srg) }

    before_all do
      Membership.find_or_create_by!(user: merge_admin, membership: project) { |m| m.role = 'admin' }
      Membership.find_or_create_by!(user: merge_author, membership: project) { |m| m.role = 'author' }
      Membership.find_or_create_by!(user: merge_commenter, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: merge_other_commenter, membership: project) { |m| m.role = 'viewer' }
      Membership.find_or_create_by!(user: merge_commenter, membership: merge_other_project) { |m| m.role = 'viewer' }
    end

    let(:m_rule_a) { component.rules.first }
    let(:m_rule_b) { component.rules.second }
    let(:m_rule_c) { component.rules.third }
    let!(:survivor) do
      create(:review, :comment, comment: 'logging not applicable', user: merge_commenter,
                                rule: m_rule_a, section: nil)
    end
    let!(:dup_b) do
      create(:review, :comment, comment: 'logging not applicable', user: merge_commenter,
                                rule: m_rule_b, section: nil)
    end
    let!(:dup_c) do
      create(:review, :comment, comment: 'logging not applicable', user: merge_commenter,
                                rule: m_rule_c, section: nil)
    end

    context 'as a project admin' do
      before { sign_in merge_admin }

      it 'merges secondaries into the chosen survivor' do
        patch '/reviews/merge', params: {
          review_ids: [survivor.id, dup_b.id, dup_c.id],
          survivor_id: survivor.id
        }, as: :json

        expect(response).to have_http_status(:ok)
        [dup_b, dup_c].each do |d|
          d.reload
          expect(d.triage_status).to eq('duplicate')
          expect(d.duplicate_of_review_id).to eq(survivor.id)
          expect(d.adjudicated_at).to be_within(5.seconds).of(Time.current)
        end
        expect(survivor.reload.comment).to include('[Merged: originally posted on')
      end

      it 'rejects merging comments from different commenters' do
        foreign = create(:review, :comment, comment: 'similar concern, different commenter',
                                            user: merge_other_commenter, rule: m_rule_b, section: nil)
        patch '/reviews/merge', params: {
          review_ids: [survivor.id, foreign.id],
          survivor_id: survivor.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(foreign.reload.triage_status).to eq('pending')
      end

      it 'rejects merging across components' do
        foreign = create(:review, :comment, comment: 'other-component concern', user: merge_commenter,
                                            rule: merge_other_component.rules.first, section: nil)
        patch '/reviews/merge', params: {
          review_ids: [survivor.id, foreign.id],
          survivor_id: survivor.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(foreign.reload.triage_status).to eq('pending')
      end

      it 'rejects when the survivor is not one of the selected comments' do
        patch '/reviews/merge', params: {
          review_ids: [dup_b.id, dup_c.id],
          survivor_id: survivor.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(dup_b.reload.triage_status).to eq('pending')
      end
    end

    context 'as a project author (non-admin)' do
      before { sign_in merge_author }

      it 'forbids the merge' do
        patch '/reviews/merge', params: {
          review_ids: [survivor.id, dup_b.id],
          survivor_id: survivor.id
        }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(dup_b.reload.triage_status).to eq('pending')
      end
    end
  end
end
