# frozen_string_literal: true

require 'rails_helper'

# Requirement: serialized has_many collections must come out in a deterministic
# TOTAL order so two identical API reads never differ (the ordering flake).
# Non-rule collections use two shared in-memory sorters on ApplicationRecord
# (rule collections use BaseRule.canonical_sort, the version-based variant):
#   - sorted_by_id  : stable creation order, id as the total-order key
#   - chronological : created_at then id, so id breaks created_at ties
# Both sort ALREADY-LOADED collections in Ruby (zero re-query / no N+1).
RSpec.describe 'Deterministic serialized-collection ordering' do
  describe 'ApplicationRecord.sorted_by_id' do
    it 'orders a loaded collection by id ascending, regardless of input order' do
      a = create(:user)
      b = create(:user)
      c = create(:user)

      expect(ApplicationRecord.sorted_by_id([c, a, b]).map(&:id)).to eq([a, b, c].map(&:id))
    end
  end

  describe 'ApplicationRecord.chronological' do
    it 'orders by created_at then id, with id breaking created_at ties' do
      tie = Time.utc(2020, 1, 1, 12, 0, 0)
      a = create(:user)
      b = create(:user)
      c = create(:user)
      a.update_column(:created_at, tie + 10.seconds) # newest
      b.update_column(:created_at, tie)              # tie with c; lower id -> first
      c.update_column(:created_at, tie)              # tie with b; higher id -> second

      ordered = ApplicationRecord.chronological([a, b, c])
      expect(ordered.map(&:id)).to eq([b.id, c.id, a.id])
    end
  end

  describe 'ApplicationRecord#histories' do
    let_it_be(:component) { create(:component, :skip_rules) }

    it 'orders audits by created_at then id (id breaks same-timestamp ties)' do
      tie = Time.utc(2020, 1, 1, 12, 0, 0)
      component.update!(name: 'first change')
      component.update!(name: 'second change')
      # Force both audits to the same created_at so only the :id tiebreak
      # can produce a deterministic order.
      component.audits.each { |a| a.update_column(:created_at, tie) }

      ids = component.own_and_associated_audits.order(:created_at, :id).pluck(:id)
      expect(component.histories(nil).pluck(:id)).to eq(ids)
    end
  end

  describe 'Component#reviews' do
    let_it_be(:component) { create(:component, :skip_rules) }
    let_it_be(:rule) { create(:rule, component: component) }

    it 'returns reviews in a deterministic order when created_at ties' do
      tie = Time.utc(2020, 1, 1, 12, 0, 0)
      r1 = create(:review, :comment, rule: rule, user: create(:user))
      r2 = create(:review, :comment, rule: rule, user: create(:user))
      [r1, r2].each { |r| r.update_column(:created_at, tie) }

      # Most-recent-first with id as the tiebreak => higher id first.
      expect(component.reviews.pluck('id')).to eq([r2.id, r1.id])
    end
  end
end
