# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::ReviewMatcher, type: :service do
  let(:base_review) do
    {
      'rule_id' => 'V-12345',
      'created_at' => '2026-06-06T10:23:45.123456',
      'comment' => 'Looks good',
      'external_id' => 1
    }
  end

  describe '#match' do
    it 'matches reviews by (rule_id, created_at, comment_digest) composite key' do
      ours = [base_review.dup]
      theirs = [base_review.dup]

      result = described_class.new(ours_reviews: ours, theirs_reviews: theirs).match

      expect(result.matched.size).to eq(1)
      expect(result.matched.first[:ours]).to eq(ours.first)
      expect(result.matched.first[:theirs]).to eq(theirs.first)
      expect(result.only_ours).to be_empty
      expect(result.only_theirs).to be_empty
    end

    it 'sends differing rule_id to only_ours / only_theirs' do
      ours = [base_review.merge('rule_id' => 'V-1')]
      theirs = [base_review.merge('rule_id' => 'V-2')]

      result = described_class.new(ours_reviews: ours, theirs_reviews: theirs).match

      expect(result.matched).to be_empty
      expect(result.only_ours.size).to eq(1)
      expect(result.only_theirs.size).to eq(1)
    end

    it 'sends differing comment text to only_ours / only_theirs' do
      ours = [base_review.merge('comment' => 'A')]
      theirs = [base_review.merge('comment' => 'B')]

      result = described_class.new(ours_reviews: ours, theirs_reviews: theirs).match

      expect(result.matched).to be_empty
      expect(result.only_ours.size).to eq(1)
      expect(result.only_theirs.size).to eq(1)
    end

    it 'sends differing created_at (microsecond) to only_ours / only_theirs by default' do
      ours = [base_review.merge('created_at' => '2026-06-06T10:23:45.111111')]
      theirs = [base_review.merge('created_at' => '2026-06-06T10:23:45.222222')]

      result = described_class.new(ours_reviews: ours, theirs_reviews: theirs).match

      expect(result.matched).to be_empty
      expect(result.only_ours.size).to eq(1)
      expect(result.only_theirs.size).to eq(1)
    end
  end

  describe '.digest' do
    it 'computes SHA-256[0..15] (16 hex chars = 64 bits) of NFC-normalized comment' do
      expect(described_class.digest('hello')).to match(/\A[0-9a-f]{16}\z/)
    end

    it 'is stable across calls with identical input' do
      first = described_class.digest('foo')
      second = described_class.digest('foo')
      expect(first).to eq(second)
    end

    it 'NFC-normalizes Unicode equivalent forms (composed vs decomposed)' do
      composed = 'café'      # café — single composed codepoint U+00E9
      decomposed = 'café'   # café — 'e' + combining acute U+0301

      expect(composed).not_to eq(decomposed) # raw strings differ
      expect(described_class.digest(composed)).to eq(described_class.digest(decomposed))
    end

    it 'treats nil comment as empty string' do
      expect(described_class.digest(nil)).to eq(described_class.digest(''))
    end

    it 'distinguishes different content' do
      expect(described_class.digest('foo')).not_to eq(described_class.digest('bar'))
    end
  end

  describe 'degenerate collisions (same rule, same second, same text)' do
    let(:k_attrs) do
      { 'rule_id' => 'V-1', 'created_at' => '2026-06-06T10:23:45.000000', 'comment' => 'same' }
    end

    it 'tiebreaks degenerate collisions by external_id position (sorted ascending)' do
      # Two reviews per side with identical composite keys; only external_id distinguishes them.
      ours = [
        k_attrs.merge('external_id' => 2),
        k_attrs.merge('external_id' => 1)
      ]
      theirs = [
        k_attrs.merge('external_id' => 11),
        k_attrs.merge('external_id' => 10)
      ]

      result = described_class.new(ours_reviews: ours, theirs_reviews: theirs).match

      pairs = result.matched.map { |m| [m[:ours]['external_id'], m[:theirs]['external_id']] }
      expect(pairs).to eq([[1, 10], [2, 11]])
    end

    it 'logs collisions even when fully paired so MergePlan can surface a warning' do
      ours = [k_attrs.merge('external_id' => 1), k_attrs.merge('external_id' => 2)]
      theirs = [k_attrs.merge('external_id' => 10), k_attrs.merge('external_id' => 11)]

      result = described_class.new(ours_reviews: ours, theirs_reviews: theirs).match

      expect(result.collisions.size).to eq(1)
      expect(result.collisions.first[:members].size).to eq(4)
    end

    it 'spills unpaired extras into only_ours / only_theirs' do
      ours = [k_attrs.merge('external_id' => 1), k_attrs.merge('external_id' => 2), k_attrs.merge('external_id' => 3)]
      theirs = [k_attrs.merge('external_id' => 10)]

      result = described_class.new(ours_reviews: ours, theirs_reviews: theirs).match

      expect(result.matched.size).to eq(1)
      expect(result.matched.first[:ours]['external_id']).to eq(1)
      expect(result.matched.first[:theirs]['external_id']).to eq(10)
      expect(result.only_ours.pluck('external_id')).to eq([2, 3])
      expect(result.only_theirs).to be_empty
    end
  end

  describe 'manifest v1.0 fallback (second-precision archives)' do
    it 'falls back to digest-heavy matching for v1.0 manifest (second precision)' do
      # Same review timestamp truncated differently on each side — pre-fix archives carry
      # second precision, current export carries microsecond. v1.0 mode normalizes both
      # to second precision before keying.
      ours = [base_review.merge('created_at' => '2026-06-06T10:23:45.987654')]
      theirs = [base_review.merge('created_at' => '2026-06-06T10:23:45')]

      result = described_class.new(
        ours_reviews: ours,
        theirs_reviews: theirs,
        manifest_version: '1.0'
      ).match

      expect(result.matched.size).to eq(1)
      expect(result.only_ours).to be_empty
      expect(result.only_theirs).to be_empty
    end

    it 'does NOT cross-match across the second boundary even in v1.0 mode' do
      ours = [base_review.merge('created_at' => '2026-06-06T10:23:45.987654')]
      theirs = [base_review.merge('created_at' => '2026-06-06T10:23:46.000000')]

      result = described_class.new(
        ours_reviews: ours,
        theirs_reviews: theirs,
        manifest_version: '1.0'
      ).match

      expect(result.matched).to be_empty
      expect(result.only_ours.size).to eq(1)
      expect(result.only_theirs.size).to eq(1)
    end
  end

  describe 'manifest v1.1 microsecond precision' do
    it 'does NOT collide two reviews 100ms apart with identical rule_id and comment into pair_degenerate' do
      ours = [
        base_review.merge('external_id' => 1, 'created_at' => '2026-06-08T15:00:00.100000'),
        base_review.merge('external_id' => 2, 'created_at' => '2026-06-08T15:00:00.200000')
      ]
      theirs = [
        base_review.merge('external_id' => 11, 'created_at' => '2026-06-08T15:00:00.100000'),
        base_review.merge('external_id' => 12, 'created_at' => '2026-06-08T15:00:00.200000')
      ]

      result = described_class.new(
        ours_reviews: ours, theirs_reviews: theirs, manifest_version: '1.1'
      ).match

      expect(result.matched.size).to eq(2)
      expect(result.collisions).to be_empty
      expect(result.only_ours).to be_empty
      expect(result.only_theirs).to be_empty
    end
  end
end
