# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Rails/SkipsModelValidations -- test setup deliberately bypasses validations
# to create specific DB states (stale FKs, nil user_id, imported attribution)
RSpec.describe Review do
  include_context 'srg model base setup'

  # `reviews` table needs two
  # nullable string columns to preserve original commenter attribution
  # when the User row gets removed (User#destroy → reviews.user_id NULL
  # via on_delete: :nullify FK in step A3) or when a json_archive import
  # carries a commenter email/name that doesn't resolve to a User on the
  # target instance. Mirrors the `_imported_email/_name` columns added in
  # `.8` for triage_set_by + adjudicated_by.
  describe 'commenter_imported_* columns' do
    it 'has commenter_imported_email column' do
      expect(Review.column_names).to include('commenter_imported_email')
    end

    it 'has commenter_imported_name column' do
      expect(Review.column_names).to include('commenter_imported_name')
    end

    it 'persists commenter_imported_email + commenter_imported_name values' do
      review = create(:review, :comment, comment: 'c', section: nil, user: p_viewer,
                                         rule: rule, triage_status: 'pending')
      review.update_columns(commenter_imported_email: 'imp@old.example',
                            commenter_imported_name: 'Imported Person')
      review.reload
      expect(review.commenter_imported_email).to eq('imp@old.example')
      expect(review.commenter_imported_name).to eq('Imported Person')
    end
  end

  describe 'attribution display helpers' do
    let(:base) do
      create(:review, :comment, comment: 'c', section: nil, user: p_viewer, rule: rule, triage_status: 'pending')
    end

    describe '#triager_display_name' do
      it 'returns the resolved User name when FK is set' do
        base.update_columns(triage_set_by_id: p_admin.id, triage_set_at: Time.current)
        expect(base.reload.triager_display_name).to eq(p_admin.name)
      end

      it 'falls back to imported_name when FK is nil' do
        base.update_columns(triage_set_by_imported_name: 'Alice Imported',
                            triage_set_by_imported_email: 'alice@old.example')
        expect(base.reload.triager_display_name).to eq('Alice Imported')
      end

      # Task 33 PII guard: redact to role label when only imported_email
      # is populated. See ImportedAttribution comment block for rationale.
      it 'redacts to "(imported triager)" when only imported_email is populated' do
        base.update_columns(triage_set_by_imported_name: nil,
                            triage_set_by_imported_email: 'bob@old.example')
        expect(base.reload.triager_display_name).to eq('(imported triager)')
      end

      it 'returns nil when nothing is set' do
        expect(base.triager_display_name).to be_nil
      end
    end

    describe '#triager_imported?' do
      it 'is false when FK is set (resolved User)' do
        base.update_columns(triage_set_by_id: p_admin.id, triage_set_at: Time.current)
        expect(base.reload.triager_imported?).to be(false)
      end

      it 'is true when FK is nil and imported attribution is present' do
        base.update_columns(triage_set_by_imported_name: 'Alice')
        expect(base.reload.triager_imported?).to be(true)
      end

      it 'is false when FK is nil and no imported attribution' do
        expect(base.triager_imported?).to be(false)
      end
    end

    describe '#adjudicator_display_name' do
      it 'returns the resolved User name when FK is set' do
        base.update_columns(adjudicated_by_id: p_admin.id, adjudicated_at: Time.current)
        expect(base.reload.adjudicator_display_name).to eq(p_admin.name)
      end

      it 'falls back to imported_name when FK is nil' do
        base.update_columns(adjudicated_by_imported_name: 'Carol Imported',
                            adjudicated_by_imported_email: 'carol@old.example')
        expect(base.reload.adjudicator_display_name).to eq('Carol Imported')
      end

      # Task 33 PII guard: redact to role label when only imported_email
      # is populated. See ImportedAttribution comment block for rationale.
      it 'redacts to "(imported adjudicator)" when only imported_email is populated' do
        base.update_columns(adjudicated_by_imported_email: 'dan@old.example')
        expect(base.reload.adjudicator_display_name).to eq('(imported adjudicator)')
      end

      it 'returns nil when nothing is set' do
        expect(base.adjudicator_display_name).to be_nil
      end
    end

    describe '#adjudicator_imported?' do
      it 'is false when FK is set' do
        base.update_columns(adjudicated_by_id: p_admin.id, adjudicated_at: Time.current)
        expect(base.reload.adjudicator_imported?).to be(false)
      end

      it 'is true when FK is nil and imported attribution is present' do
        base.update_columns(adjudicated_by_imported_email: 'dan@old.example')
        expect(base.reload.adjudicator_imported?).to be(true)
      end

      it 'is false when FK is nil and no imported attribution' do
        expect(base.adjudicator_imported?).to be(false)
      end
    end
  end

  # commenter display helpers
  # mirror the triager_*/adjudicator_* pattern from .8. Used by display
  # surfaces (CommentTriageModal, CSV export, blueprint) so the fallback
  # is one source of truth: resolved User name → imported_name →
  # imported_email → nil.
  describe 'commenter display helpers' do
    let(:base) do
      create(:review, :comment, comment: 'c', section: nil, user: p_viewer, rule: rule, triage_status: 'pending')
    end

    describe '#commenter_display_name' do
      it 'returns the resolved User name when user_id is set' do
        expect(base.commenter_display_name).to eq(p_viewer.name)
      end

      it 'falls back to commenter_imported_name when user_id is nil' do
        base.update_columns(user_id: nil,
                            commenter_imported_name: 'Imported Person',
                            commenter_imported_email: 'imp@old.example')
        expect(base.reload.commenter_display_name).to eq('Imported Person')
      end

      # Task 33 PII guard: when ONLY imported_email is populated, the
      # display fallback is a redacted role label rather than the raw
      # email. JSON archives can carry real source-instance emails;
      # surfacing them through any read surface is a scrape vector.
      it 'redacts to "(imported commenter)" when only imported_email is populated' do
        base.update_columns(user_id: nil,
                            commenter_imported_name: nil,
                            commenter_imported_email: 'imp@old.example')
        expect(base.reload.commenter_display_name).to eq('(imported commenter)')
      end

      it 'returns nil when user_id is nil and no imported attribution' do
        base.update_columns(user_id: nil)
        expect(base.reload.commenter_display_name).to be_nil
      end
    end

    describe '#commenter_imported?' do
      it 'is false when user_id is set (resolved User)' do
        expect(base.commenter_imported?).to be(false)
      end

      it 'is true when user_id is nil and imported attribution is present' do
        base.update_columns(user_id: nil, commenter_imported_email: 'imp@old.example')
        expect(base.reload.commenter_imported?).to be(true)
      end

      it 'is false when user_id is nil and no imported attribution' do
        base.update_columns(user_id: nil)
        expect(base.reload.commenter_imported?).to be(false)
      end
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
