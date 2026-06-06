# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Component do
  describe 'comment phase' do
    let(:component) { create(:component, :skip_rules) }

    it 'defaults to open' do
      expect(component.comment_phase).to eq('open')
    end

    it 'rejects an invalid phase' do
      component.comment_phase = 'whatever'
      expect(component).not_to be_valid
      expect(component.errors[:comment_phase].join).to match(/included in the list/i)
    end

    describe 'closed_reason' do
      it 'permits adjudicating + finalized when phase is closed' do
        %w[adjudicating finalized].each do |reason|
          component.comment_phase = 'closed'
          component.closed_reason = reason
          expect(component).to be_valid, "unexpectedly invalid for closed_reason=#{reason}"
        end
      end

      it 'permits null when phase is closed (closed without a reason)' do
        component.comment_phase = 'closed'
        component.closed_reason = nil
        expect(component).to be_valid
      end

      it 'rejects closed_reason on an open component' do
        component.comment_phase = 'open'
        component.closed_reason = 'adjudicating'
        expect(component).not_to be_valid
        expect(component.errors[:closed_reason].join).to match(/comment_phase is "closed"/)
      end

      it 'rejects an invalid closed_reason value' do
        component.comment_phase = 'closed'
        component.closed_reason = 'mystery'
        expect(component).not_to be_valid
        expect(component.errors[:closed_reason].join).to match(/included in the list/i)
      end
    end

    describe '#accepting_new_comments?' do
      it 'is true only when phase is open' do
        component.comment_phase = 'open'
        expect(component.accepting_new_comments?).to be(true)
        component.comment_phase = 'closed'
        expect(component.accepting_new_comments?).to be(false)
      end
    end

    describe '#triaging_active?' do
      it 'is true for open and for closed+adjudicating' do
        component.comment_phase = 'open'
        expect(component.triaging_active?).to be(true)

        component.comment_phase = 'closed'
        component.closed_reason = 'adjudicating'
        expect(component.triaging_active?).to be(true)
      end

      it 'is false for closed+finalized and closed-without-reason' do
        component.comment_phase = 'closed'
        component.closed_reason = 'finalized'
        expect(component.triaging_active?).to be(false)

        component.closed_reason = nil
        expect(component.triaging_active?).to be(false)
      end
    end

    describe '#comment_period_days_remaining' do
      it 'returns nil when comments are closed' do
        component.comment_phase = 'closed'
        component.comment_period_ends_at = 5.days.from_now
        expect(component.comment_period_days_remaining).to be_nil
      end

      it 'returns days remaining when open with a future end date' do
        component.comment_phase = 'open'
        component.comment_period_ends_at = 5.days.from_now
        expect(component.comment_period_days_remaining).to eq(5)
      end

      it 'returns nil when open without an end date' do
        component.comment_phase = 'open'
        component.comment_period_ends_at = nil
        expect(component.comment_period_days_remaining).to be_nil
      end

      it 'returns nil when open but the end date is in the past' do
        component.comment_phase = 'open'
        component.comment_period_ends_at = 2.days.ago
        expect(component.comment_period_days_remaining).to be_nil
      end

      it 'returns 1 when end date is less than 24 hours away (ceil rounding)' do
        component.comment_phase = 'open'
        component.comment_period_ends_at = 12.hours.from_now
        expect(component.comment_period_days_remaining).to eq(1)
      end
    end

    describe '#frozen_for_writes?' do
      it 'is true only when closed+finalized' do
        component.comment_phase = 'open'
        expect(component.frozen_for_writes?).to be(false)

        component.comment_phase = 'closed'
        component.closed_reason = 'adjudicating'
        expect(component.frozen_for_writes?).to be(false)

        component.closed_reason = nil
        expect(component.frozen_for_writes?).to be(false)

        component.closed_reason = 'finalized'
        expect(component.frozen_for_writes?).to be(true)
      end
    end

    # Phase transitions are unrestricted at the model layer — compliance
    # lives in the audit trail (vulcan_audited captures every change) and
    # in frozen_for_writes? which blocks Review writes whenever the
    # component IS currently closed+finalized regardless of how it got
    # there. Locking transitions would block legitimate admin operations
    # (correcting an accidental click, reopening for post-publication
    # issues) without adding compliance value.
    describe 'phase transitions are unrestricted (admin authority)' do
      it 'allows closed+finalized → open' do
        component.update!(comment_phase: 'closed', closed_reason: 'finalized')
        component.comment_phase = 'open'
        component.closed_reason = nil
        expect(component).to be_valid
      end

      it 'allows closed+finalized → closed+adjudicating' do
        component.update!(comment_phase: 'closed', closed_reason: 'finalized')
        component.closed_reason = 'adjudicating'
        expect(component).to be_valid
      end

      it 'allows open → closed+finalized in a single update' do
        component.update!(comment_phase: 'open')
        component.comment_phase = 'closed'
        component.closed_reason = 'finalized'
        expect(component).to be_valid
      end
    end
  end

  describe '#metadata' do
    it 'returns nil when component_metadata is absent' do
      comp = create(:component, :skip_rules)
      expect(comp.metadata).to be_nil
    end
  end
end
