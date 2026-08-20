# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews' do
  include_context 'reviews request base setup'

  describe 'PATCH /reviews/bulk_triage' do
    let_it_be(:bulk_triager) { create(:user) }
    let_it_be(:bulk_commenter) { create(:user) }
    let_it_be(:bulk_other_project) { create(:project) }
    let_it_be(:bulk_other_component) { create(:component, project: bulk_other_project, based_on: srg) }

    before_all do
      Membership.find_or_create_by!(user: bulk_triager, membership: project) { |m| m.role = 'author' }
      # Author on the other project too, so the cross-component test exercises
      # the business rule (422) rather than a concealment denial (404).
      Membership.find_or_create_by!(user: bulk_triager, membership: bulk_other_project) { |m| m.role = 'author' }
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
        before_call = Time.current.floor(6)
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'informational',
          response_comment: 'Acknowledged — no change required.'
        }, as: :json
        after_call = Time.current

        expect(response).to have_http_status(:ok)

        [comment_a, comment_b].each do |c|
          c.reload
          expect(c.triage_status).to eq('informational')
          expect(c.triage_set_by_id).to eq(bulk_triager.id)
          expect(c.triage_set_at).to be_between(before_call, after_call)
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

      it 'applies duplicate with a shared canonical target to every selected comment' do
        canonical = create(:review, :comment, comment: 'the canonical logging thread',
                                              user: bulk_commenter, rule: rule_a, section: 'check_content')
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'duplicate',
          duplicate_of_review_id: canonical.id
        }, as: :json

        expect(response).to have_http_status(:ok)
        [comment_a, comment_b].each do |c|
          c.reload
          expect(c.triage_status).to eq('duplicate')
          expect(c.duplicate_of_review_id).to eq(canonical.id)
          expect(c.adjudicated_at).to be_present
        end
      end

      it 'applies addressed_by with one shared target rule across a selection spanning rules' do
        target_rule = component.rules.third
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'addressed_by',
          addressed_by_rule_id: target_rule.id
        }, as: :json

        expect(response).to have_http_status(:ok)
        [comment_a, comment_b].each do |c|
          c.reload
          expect(c.triage_status).to eq('addressed_by')
          expect(c.addressed_by_rule_id).to eq(target_rule.id)
          expect(c.duplicate_of_review_id).to be_nil
          expect(c.adjudicated_at).to be_present
        end
      end

      it 'rejects a canonical target that is among the selected comments, atomically' do
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'duplicate',
          duplicate_of_review_id: comment_b.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message'))
          .to include('The canonical target cannot be among the selected comments.')
        expect(comment_a.reload.triage_status).to eq('pending')
        expect(comment_b.reload.triage_status).to eq('pending')
      end

      it 'rejects bulk duplicate without a target (shared validation with per-comment triage)' do
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'duplicate'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(comment_a.reload.triage_status).to eq('pending')
      end

      it 'inherits the same-component validator: a cross-component canonical fails the batch' do
        foreign_canonical = create(:review, :comment, comment: 'other component thread',
                                                      user: bulk_commenter,
                                                      rule: bulk_other_component.rules.first, section: nil)
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'duplicate',
          duplicate_of_review_id: foreign_canonical.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(comment_a.reload.triage_status).to eq('pending')
        expect(comment_b.reload.triage_status).to eq('pending')
      end

      it 'inherits the chained-duplicate rejection: a canonical that is itself a duplicate fails the batch' do
        base = create(:review, :comment, comment: 'ultimate canonical', user: bulk_commenter,
                                         rule: rule_a, section: 'check_content')
        chained = create(:review, :comment, :duplicate, comment: 'already a duplicate',
                                                        user: bulk_commenter, rule: rule_a,
                                                        duplicate_of_review_id: base.id)
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'duplicate',
          duplicate_of_review_id: chained.id
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'title')).to eq('Could not save triage.')
        expect(comment_a.reload.triage_status).to eq('pending')
        expect(comment_b.reload.triage_status).to eq('pending')
      end

      it 'auto-adjudicates every terminal status through the bulk path' do
        canonical = create(:review, :comment, comment: 'terminal canonical', user: bulk_commenter,
                                              rule: rule_a, section: 'check_content')
        target_params = {
          'duplicate' => { duplicate_of_review_id: canonical.id },
          'informational' => {},
          'withdrawn' => {},
          'addressed_by' => { addressed_by_rule_id: component.rules.third.id }
        }
        expect(target_params.keys).to match_array(Review::TERMINAL_AUTO_ADJUDICATE_STATUSES)

        target_params.each do |status, extra|
          subject_comment = create(:review, :comment, comment: "terminal probe #{status}",
                                                      user: bulk_commenter, rule: rule_b,
                                                      section: 'fixtext')
          patch '/reviews/bulk_triage',
                params: { review_ids: [subject_comment.id], triage_status: status }.merge(extra),
                as: :json

          expect(response).to have_http_status(:ok), "#{status}: #{response.body}"
          expect(subject_comment.reload.adjudicated_at).to be_present, "#{status} did not auto-adjudicate"
        end
      end

      it 'leaves adjudicated_at nil for a non-terminal bulk status' do
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'concur'
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(comment_a.reload.adjudicated_at).to be_nil
        expect(comment_b.reload.adjudicated_at).to be_nil
      end

      it 'normalizes a stray target on a non-target status instead of storing it' do
        canonical = create(:review, :comment, comment: 'stray target', user: bulk_commenter,
                                              rule: rule_a, section: 'check_content')
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_a.id, comment_b.id],
          triage_status: 'concur',
          duplicate_of_review_id: canonical.id
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(comment_a.reload.triage_status).to eq('concur')
        expect(comment_a.duplicate_of_review_id).to be_nil
        expect(comment_b.reload.duplicate_of_review_id).to be_nil
      end

      it 'rolls the whole batch back when one member fails validation (a reply cannot hold a triage status)' do
        reply = create(:review, :reply, comment: 'a threaded reply', user: bulk_commenter,
                                        rule: rule_a, responding_to_review_id: comment_a.id)
        patch '/reviews/bulk_triage', params: {
          review_ids: [comment_b.id, reply.id],
          triage_status: 'informational'
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(comment_b.reload.triage_status).to eq('pending')
        expect(reply.reload.triage_status).to be_nil
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

    # A stranger to a hidden project must not learn a review exists by bulk-
    # triaging it: the denial is concealed as a 404 identical to a nonexistent id.
    context 'as a stranger to a hidden project (concealment, no oracle)' do
      let_it_be(:bulk_stranger) { create(:user) }

      before { sign_in bulk_stranger }

      it 'answers a hidden-project review identically to a nonexistent id (404 not_found)' do
        foreign = create(:review, :comment, comment: 'hidden concern', user: bulk_commenter,
                                            rule: bulk_other_component.rules.first, section: nil)
        patch '/reviews/bulk_triage',
              params: { review_ids: [foreign.id], triage_status: 'informational' }, as: :json
        concealed = { status: response.status, body: response.body }

        patch '/reviews/bulk_triage',
              params: { review_ids: [999_999_999], triage_status: 'informational' }, as: :json
        missing = { status: response.status, body: response.body }

        expect(concealed[:status]).to eq(404)
        expect(response.parsed_body['type']).to eq('/docs/api/errors#not_found')
        expect(concealed).to eq(missing)
      end
    end
  end

  # A response comment must land on its PARENT'S commentable — the Rule-classed
  # association returns nil for authored SrgRules and component-scoped parents,
  # which left the response with no commentable (422) before the fix.
  describe 'PATCH /reviews/bulk_triage responses on srg-kind and component-scoped parents' do
    let_it_be(:srg_author) { create(:user) }
    let_it_be(:srg_project) { create(:project) }
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: srg_project, document_type: 'srg', prefix: 'SRGX-00',
                                      name: 'Authored SRG bulk', title: 'Authored SRG bulk')
    end
    let_it_be(:authored_a) { create(:srg_rule, :authored, component: srg_component, rule_id: '000001') }
    let_it_be(:authored_b) { create(:srg_rule, :authored, component: srg_component, rule_id: '000002') }

    before_all do
      Membership.find_or_create_by!(user: srg_author, membership: srg_project) { |m| m.role = 'author' }
    end

    before { sign_in srg_author }

    it 'creates each response on the parent authored requirement' do
      one = create(:review, :comment, user: srg_author, rule: nil, commentable: authored_a,
                                      comment: 'srg feedback one', section: 'fixtext')
      two = create(:review, :comment, user: srg_author, rule: nil, commentable: authored_b,
                                      comment: 'srg feedback two', section: 'fixtext')

      patch '/reviews/bulk_triage', params: {
        review_ids: [one.id, two.id],
        triage_status: 'informational',
        response_comment: 'Acknowledged for the authored requirement.'
      }, as: :json

      expect(response).to have_http_status(:ok)
      [one, two].each do |parent|
        resp = Review.find_by!(responding_to_review_id: parent.id)
        expect(resp.commentable_type).to eq('BaseRule')
        expect(resp.commentable_id).to eq(parent.commentable_id)
        expect(resp.rule_id).to eq(parent.commentable_id)
      end
    end

    it 'creates the response on the component for a component-scoped parent' do
      parent = create(:review, :component_comment, user: srg_author, commentable: srg_component,
                                                   comment: 'overall srg feedback')

      patch '/reviews/bulk_triage', params: {
        review_ids: [parent.id],
        triage_status: 'informational',
        response_comment: 'Noted at the component level.'
      }, as: :json

      expect(response).to have_http_status(:ok)
      resp = Review.find_by!(responding_to_review_id: parent.id)
      expect(resp.commentable_type).to eq('Component')
      expect(resp.commentable_id).to eq(srg_component.id)
      expect(resp.section).to be_nil
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
      # Admin on the other project too, so the cross-component test exercises the
      # business rule (422) rather than a concealment denial (404).
      Membership.find_or_create_by!(user: merge_admin, membership: merge_other_project) { |m| m.role = 'admin' }
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
        before_call = Time.current.floor(6)
        patch '/reviews/merge', params: {
          review_ids: [survivor.id, dup_b.id, dup_c.id],
          survivor_id: survivor.id
        }, as: :json
        after_call = Time.current

        expect(response).to have_http_status(:ok)
        [dup_b, dup_c].each do |d|
          d.reload
          expect(d.triage_status).to eq('duplicate')
          expect(d.duplicate_of_review_id).to eq(survivor.id)
          expect(d.adjudicated_at).to be_between(before_call, after_call)
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

    # A stranger to a hidden project must not learn a review exists by merging
    # it: the denial is concealed as a 404 identical to a nonexistent id.
    context 'as a stranger to a hidden project (concealment, no oracle)' do
      let_it_be(:merge_stranger) { create(:user) }

      before { sign_in merge_stranger }

      it 'answers a hidden-project review identically to a nonexistent id (404 not_found)' do
        foreign = create(:review, :comment, comment: 'hidden concern', user: merge_commenter,
                                            rule: merge_other_component.rules.first, section: nil)
        patch '/reviews/merge', params: { review_ids: [foreign.id], survivor_id: foreign.id }, as: :json
        concealed = { status: response.status, body: response.body }

        patch '/reviews/merge', params: { review_ids: [999_999_999], survivor_id: 999_999_999 }, as: :json
        missing = { status: response.status, body: response.body }

        expect(concealed[:status]).to eq(404)
        expect(response.parsed_body['type']).to eq('/docs/api/errors#not_found')
        expect(concealed).to eq(missing)
      end
    end
  end
end
