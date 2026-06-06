# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::RuleThreeWay, type: :service do
  describe '#resolve (3-way: srg_baseline provided)' do
    it 'returns :no_change when ours == theirs (both moved to the same value)' do
      tw = described_class.new(srg_baseline: { 'title' => 'srg' }, ours: { 'title' => 'X' }, theirs: { 'title' => 'X' })
      expect(tw.resolve('title')).to eq(:no_change)
    end

    it 'returns :theirs when ours == srg_baseline (we did not edit; theirs did)' do
      tw = described_class.new(srg_baseline: { 'title' => 'srg' }, ours: { 'title' => 'srg' }, theirs: { 'title' => 'T' })
      expect(tw.resolve('title')).to eq(:theirs)
    end

    it 'returns :ours when theirs == srg_baseline (they did not edit; we did)' do
      tw = described_class.new(srg_baseline: { 'title' => 'srg' }, ours: { 'title' => 'O' }, theirs: { 'title' => 'srg' })
      expect(tw.resolve('title')).to eq(:ours)
    end

    it 'returns :conflict when both diverge from srg_baseline AND from each other' do
      tw = described_class.new(srg_baseline: { 'title' => 'srg' }, ours: { 'title' => 'O' }, theirs: { 'title' => 'T' })
      expect(tw.resolve('title')).to eq(:conflict)
    end

    it 'returns :no_change when ours == theirs == srg_baseline (untouched everywhere)' do
      tw = described_class.new(srg_baseline: { 'title' => 'srg' }, ours: { 'title' => 'srg' }, theirs: { 'title' => 'srg' })
      expect(tw.resolve('title')).to eq(:no_change)
    end
  end

  describe '#resolve (2-way fallback: srg_baseline nil)' do
    it 'returns :no_change when ours == theirs' do
      tw = described_class.new(srg_baseline: nil, ours: { 'title' => 'X' }, theirs: { 'title' => 'X' })
      expect(tw.resolve('title')).to eq(:no_change)
    end

    it 'returns :conflict when ours != theirs (no baseline to attribute the change to either side)' do
      tw = described_class.new(srg_baseline: nil, ours: { 'title' => 'O' }, theirs: { 'title' => 'T' })
      expect(tw.resolve('title')).to eq(:conflict)
    end
  end

  describe '#fallback_to_two_way?' do
    it 'is true when srg_baseline is nil' do
      tw = described_class.new(srg_baseline: nil, ours: {}, theirs: {})
      expect(tw.fallback_to_two_way?).to be(true)
    end

    it 'is false when srg_baseline is a hash, even if empty' do
      tw = described_class.new(srg_baseline: {}, ours: {}, theirs: {})
      expect(tw.fallback_to_two_way?).to be(false)
    end
  end

  describe 'missing field on baseline' do
    it 'falls back to 2-way semantics for fields the baseline does not cover' do
      tw = described_class.new(
        srg_baseline: { 'other_field' => 'x' },
        ours: { 'title' => 'O' },
        theirs: { 'title' => 'O' }
      )
      expect(tw.resolve('title')).to eq(:no_change)
    end

    it 'returns :conflict when field is missing from baseline AND values differ' do
      tw = described_class.new(
        srg_baseline: { 'other_field' => 'x' },
        ours: { 'title' => 'O' },
        theirs: { 'title' => 'T' }
      )
      expect(tw.resolve('title')).to eq(:conflict)
    end
  end
end
