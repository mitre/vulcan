# frozen_string_literal: true

require 'rails_helper'

# Requirements (Postel's Law — be liberal in what you accept):
#
# 1. EXPLICIT SUFFIX — always respected, no guessing:
#    - '30s'  → 30 seconds
#    - '15m'  → 900 seconds (15 minutes)
#    - '1h'   → 3600 seconds (1 hour)
#    - Case insensitive: '30S', '15M', '1H' all work
#
# 2. PLAIN NUMBER — smart heuristic based on magnitude:
#    - 1-9:    treated as HOURS   (nobody sets a 3-second or 3-minute timeout)
#    - 10-299: treated as MINUTES (backwards compat: old default was 60 = 60 min)
#    - 300+:   treated as SECONDS (DoD standard: 900 = 15 min)
#
#    Why these ranges:
#    - Single digits: 1-8 hours covers dev to workday timeouts
#    - Two digits: 10-99 minutes covers all common minute-based configs
#    - 100-299 minutes: uncommon but possible (1h40m to ~5h)
#    - 300+ seconds: lowest practical is 300s = 5 min (DoD strict)
#
# 3. DEFAULT: 3600 seconds (1 hour) when nil, empty, or zero
#
# 4. Handles both integer (from YAML default) and string (from env var) input

RSpec.describe TimeoutParser do
  describe '.parse' do
    context 'explicit suffix — always respected literally' do
      it 'parses seconds with s suffix' do
        expect(described_class.parse('900s')).to eq(900)
      end

      it 'parses minutes with m suffix' do
        expect(described_class.parse('15m')).to eq(900)
      end

      it 'parses hours with h suffix' do
        expect(described_class.parse('1h')).to eq(3600)
      end

      it 'is case insensitive for suffixes' do
        expect(described_class.parse('900S')).to eq(900)
        expect(described_class.parse('15M')).to eq(900)
        expect(described_class.parse('2H')).to eq(7200)
      end

      it 'handles 60m as 3600 seconds' do
        expect(described_class.parse('60m')).to eq(3600)
      end

      it 'handles 30s for quick testing' do
        expect(described_class.parse('30s')).to eq(30)
      end
    end

    context 'plain single digit (1-9) — treated as hours' do
      it 'treats 1 as 1 hour = 3600 seconds' do
        expect(described_class.parse('1')).to eq(3600)
      end

      it 'treats 2 as 2 hours = 7200 seconds' do
        expect(described_class.parse('2')).to eq(7200)
      end

      it 'treats 8 as 8 hours = workday timeout' do
        expect(described_class.parse('8')).to eq(28_800)
      end

      it 'treats integer 1 as 1 hour' do
        expect(described_class.parse(1)).to eq(3600)
      end

      it 'treats 9 as 9 hours (boundary)' do
        expect(described_class.parse('9')).to eq(32_400)
      end
    end

    context 'plain number 10-299 — treated as minutes (backwards compat)' do
      it 'treats 60 as 60 minutes = 3600 seconds (old default)' do
        expect(described_class.parse('60')).to eq(3600)
      end

      it 'treats integer 60 as 60 minutes = 3600 seconds' do
        expect(described_class.parse(60)).to eq(3600)
      end

      it 'treats 15 as 15 minutes = 900 seconds' do
        expect(described_class.parse('15')).to eq(900)
      end

      it 'treats 30 as 30 minutes = 1800 seconds' do
        expect(described_class.parse('30')).to eq(1800)
      end

      it 'treats 10 as 10 minutes = 600 seconds (boundary)' do
        expect(described_class.parse('10')).to eq(600)
      end

      it 'treats 120 as 120 minutes = 7200 seconds' do
        expect(described_class.parse('120')).to eq(7200)
      end

      it 'treats 299 as 299 minutes (boundary)' do
        expect(described_class.parse('299')).to eq(17_940)
      end
    end

    context 'plain number >= 300 — treated as seconds (DoD standard)' do
      it 'treats 900 as 900 seconds (DoD 15-min standard)' do
        expect(described_class.parse('900')).to eq(900)
      end

      it 'treats 600 as 600 seconds (10 min)' do
        expect(described_class.parse('600')).to eq(600)
      end

      it 'treats 3600 as 3600 seconds (1 hour)' do
        expect(described_class.parse('3600')).to eq(3600)
      end

      it 'treats integer 3600 as 3600 seconds' do
        expect(described_class.parse(3600)).to eq(3600)
      end

      it 'treats 300 as 300 seconds (boundary)' do
        expect(described_class.parse('300')).to eq(300)
      end
    end

    context 'whitespace handling' do
      it 'strips leading and trailing whitespace' do
        expect(described_class.parse('  900  ')).to eq(900)
      end

      it 'strips whitespace with suffix' do
        expect(described_class.parse(' 15m ')).to eq(900)
      end
    end

    context 'nil, empty, or zero — returns default (3600 seconds)' do
      it 'returns 3600 for nil' do
        expect(described_class.parse(nil)).to eq(3600)
      end

      it 'returns 3600 for empty string' do
        expect(described_class.parse('')).to eq(3600)
      end

      it 'returns 3600 for zero' do
        expect(described_class.parse('0')).to eq(3600)
      end

      it 'returns 3600 for integer zero' do
        expect(described_class.parse(0)).to eq(3600)
      end
    end

    context 'real-world backwards compatibility scenarios' do
      it 'old default of 60 still produces 1 hour' do
        expect(described_class.parse(60)).to eq(3600)
      end

      it 'old "quick timeout" of 5 still produces 5 hours' do
        # Single digit = hours in the new heuristic
        expect(described_class.parse(5)).to eq(18_000)
      end

      it 'old "long timeout" of 120 still produces 2 hours' do
        expect(described_class.parse(120)).to eq(7200)
      end

      it 'new DoD standard of 900 produces 15 minutes' do
        expect(described_class.parse(900)).to eq(900)
      end

      it 'someone setting 1 gets 1 hour' do
        expect(described_class.parse(1)).to eq(3600)
      end
    end
  end
end
