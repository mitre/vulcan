# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Rails/SkipsModelValidations -- test setup deliberately bypasses validations
# to create specific DB states (stale FKs, nil user_id, imported attribution)
RSpec.describe Review do
  include_context 'srg model base setup'

  # DB-layer FK constraints
  # on `reviews.user_id` and `reviews.rule_id`. Pre-.j4a, neither column
  # had a Postgres FK constraint at all, despite the model-level
  # belongs_to declarations. Failure modes:
  # - Direct SQL DELETE on a User orphaned every review (next read 500'd
  #   on `User must exist`).
  # - Direct SQL DELETE on a base_rules row orphaned every review
  #   (matching the pattern reviews_spec covers as "responding_to" via
  #   the existing self-FK).
  # The migrations use Strong Migrations 2-pass (`validate: false` +
  # separate `validate_foreign_key`) to avoid an ACCESS EXCLUSIVE table
  # lock during validation on production. Behavioral integration ("user
  # destroyed → review keeps commenter_imported_*") lands in step D1.
  # FK on `reviews.rule_id` →
  # `base_rules.id`. The card description proposed `on_delete: :cascade`
  # to "match Rule#has_many :reviews, dependent: :destroy", but the .4
  # cascade-ownership lesson applies (memory `vulcan-cascade-rails-owns`):
  # PG FK :cascade skips Rails callbacks → audited gem doesn't capture
  # per-row destroy events. Use :restrict instead. Rails-side
  # dependent: :destroy walks children-first; the FK is the safety net
  # for direct SQL DELETE FROM base_rules.
  describe 'FK constraint on reviews.rule_id' do
    let(:rule_fk) do
      ActiveRecord::Base.connection.foreign_keys(:reviews).find { |fk| fk.column == 'rule_id' }
    end

    it 'exists' do
      expect(rule_fk).not_to be_nil
    end

    it 'references the base_rules table' do
      expect(rule_fk.to_table).to eq('base_rules')
    end

    it 'has on_delete: :restrict (forces use of Rails path → audits captured)' do
      expect(rule_fk.on_delete).to eq(:restrict)
    end

    it 'is validated (not pending)' do
      expect(rule_fk.options[:validate]).to be(true)
    end
  end

  # original lifecycle migration
  # (20260429145530_add_lifecycle_columns_to_reviews) added 4 FKs inline
  # with column adds. Rails 8 default add_foreign_key validates eagerly
  # (ACCESS EXCLUSIVE on `reviews` for the duration of validation —
  # fine on empty dev DBs, painful on a populated production reviews
  # table). Strong Migrations 2-pass remediation: original migration
  # uses validate: false; companion migration runs validate_foreign_key
  # inside disable_ddl_transaction!. Three FKs apply (responding_to_review_id
  # was already 2-pass-fixed in .4 commit 33b2bea / migration 20260502080000).
  describe 'lifecycle FK constraints validated' do
    let(:fks) { ActiveRecord::Base.connection.foreign_keys(:reviews) }

    {
      'triage_set_by_id' => { to: 'users', on_delete: :nullify },
      'adjudicated_by_id' => { to: 'users', on_delete: :nullify },
      'duplicate_of_review_id' => { to: 'reviews', on_delete: :nullify }
    }.each do |column, expected|
      it "FK on #{column} exists, references #{expected[:to]}, validated" do
        fk = fks.find { |f| f.column == column }
        expect(fk).not_to be_nil
        expect(fk.to_table).to eq(expected[:to])
        expect(fk.on_delete).to eq(expected[:on_delete])
        expect(fk.options[:validate]).to be(true)
      end
    end
  end

  describe 'FK constraint on reviews.user_id' do
    let(:user_fk) do
      ActiveRecord::Base.connection.foreign_keys(:reviews).find { |fk| fk.column == 'user_id' }
    end

    it 'exists' do
      expect(user_fk).not_to be_nil
    end

    it 'references the users table' do
      expect(user_fk.to_table).to eq('users')
    end

    it 'has on_delete: :nullify (User destroy preserves the review)' do
      expect(user_fk.on_delete).to eq(:nullify)
    end

    it 'is validated (not pending)' do
      # The 2-pass Strong Migrations pattern adds the FK with
      # validate: false then runs validate_foreign_key in a separate
      # migration. The FK should be in the validated state at the end.
      expect(user_fk.options[:validate]).to be(true)
    end
  end

  # `belongs_to :user` becomes
  # optional so a Review can persist with `user_id` NULL after step A3
  # adds the FK with `on_delete: :nullify` (User#destroy nullifies all
  # the user's reviews instead of forcing a cascade). The commenter's
  # original attribution lives in `commenter_imported_*` once nullified;
  # display + export layers fall back to those columns when user_id is nil.
  describe 'belongs_to :user is optional' do
    it 'is valid with user_id nil and commenter_imported_* present' do
      review = create(:review, :comment, comment: 'c', section: nil, user: p_viewer,
                                         rule: rule, triage_status: 'pending')
      review.update_columns(user_id: nil,
                            commenter_imported_email: 'former@example.com',
                            commenter_imported_name: 'Former User')
      review.reload
      expect(review).to be_valid
    end

    it 'is valid with user_id nil even without imported attribution (FK nullified)' do
      # Loose validity at the model layer — the row can persist without
      # a user FK. Display layer handles the "no commenter" case via
      # commenter_display_name (step B1).
      review = create(:review, :comment, comment: 'c', section: nil, user: p_viewer,
                                         rule: rule, triage_status: 'pending')
      review.update_columns(user_id: nil)
      review.reload
      expect(review).to be_valid
    end
  end

  describe 'CHECK constraints — non-bypassable FK consistency' do
    let_it_be(:chk_user) { create(:user) }
    let_it_be(:chk_project) { create(:project) }
    let_it_be(:chk_srg) { create(:security_requirements_guide) }
    let_it_be(:chk_component) { create(:component, project: chk_project, based_on: chk_srg) }
    let(:chk_rule) { chk_component.rules.first }

    before_all do
      Membership.find_or_create_by!(user: chk_user, membership: chk_project) { |m| m.role = 'author' }
    end

    it 'DB rejects duplicate_of_review_id when triage_status is not duplicate' do
      review = create(:review, :comment, comment: 'test', section: nil, user: chk_user, rule: chk_rule)
      expect do
        review.update_columns(triage_status: 'concur', duplicate_of_review_id: review.id)
      end.to raise_error(ActiveRecord::StatementInvalid, /chk_review_duplicate_fk_consistency/)
    end

    it 'DB rejects addressed_by_rule_id when triage_status is not addressed_by' do
      review = create(:review, :comment, comment: 'test', section: nil, user: chk_user, rule: chk_rule)

      expect do
        review.update_columns(triage_status: 'concur', addressed_by_rule_id: chk_rule.id)
      end.to raise_error(ActiveRecord::StatementInvalid, /chk_review_addressed_by_fk_consistency/)
    end

    it 'DB allows duplicate_of_review_id when triage_status IS duplicate' do
      survivor = create(:review, :comment, comment: 'survivor', section: nil, user: chk_user, rule: chk_rule)
      review = create(:review, :comment, comment: 'dup', section: nil, user: chk_user, rule: chk_rule)

      review.update_columns(triage_status: 'duplicate', duplicate_of_review_id: survivor.id)
      review.reload
      expect(review.triage_status).to eq('duplicate')
      expect(review.duplicate_of_review_id).to eq(survivor.id)
    end

    it 'DB allows addressed_by_rule_id when triage_status IS addressed_by' do
      review = create(:review, :comment, comment: 'ab', section: nil, user: chk_user, rule: chk_rule)

      review.update_columns(triage_status: 'addressed_by', addressed_by_rule_id: chk_rule.id)
      review.reload
      expect(review.triage_status).to eq('addressed_by')
      expect(review.addressed_by_rule_id).to eq(chk_rule.id)
    end

    it 'DB rejects NULL triage_status with non-null duplicate_of_review_id' do
      review = create(:review, :comment, comment: 'null gap', section: nil, user: chk_user, rule: chk_rule)

      expect do
        review.update_columns(triage_status: nil, duplicate_of_review_id: review.id)
      end.to raise_error(ActiveRecord::StatementInvalid, /chk_review_duplicate_fk_consistency/)
    end

    it 'DB rejects NULL triage_status with non-null addressed_by_rule_id' do
      review = create(:review, :comment, comment: 'null gap ab', section: nil, user: chk_user, rule: chk_rule)

      expect do
        review.update_columns(triage_status: nil, addressed_by_rule_id: chk_rule.id)
      end.to raise_error(ActiveRecord::StatementInvalid, /chk_review_addressed_by_fk_consistency/)
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations
