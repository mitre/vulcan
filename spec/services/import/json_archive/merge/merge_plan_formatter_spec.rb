# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::MergePlanFormatter, type: :service do
  let(:plan) do
    Import::JsonArchive::Merge::MergePlan.new(
      component_id: 42, strategy: 'default', manifest: { 'backup_format_version' => '1.1' }
    )
  end
  let(:formatter) { described_class.new(plan) }

  describe '#render' do
    it 'prints a header with component id and manifest version' do
      out = formatter.render
      expect(out).to include('=== Merge Plan ===')
      expect(out).to include('Component:        42')
      expect(out).to include('Manifest version: 1.1')
    end

    it 'prints per-entity matched/only_ours/only_theirs counts' do
      plan.add_rule_partition(matched: [1, 2], only_ours: [3], only_theirs: [4, 5])
      out = formatter.render
      expect(out).to include('rules:')
      expect(out).to include('matched=2')
      expect(out).to include('only_ours=1')
      expect(out).to include('only_theirs=2')
    end

    it 'lists auto-merged field changes' do
      change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'title', from: 'A', to: 'B', resolution: :auto_theirs, locked: false, reason: ''
      )
      plan.add_field_changes('V-1', [change])

      out = formatter.render
      expect(out).to match(/Auto-merged: 1 field change/)
      expect(out).to include('title')
      expect(out).to include('A → B')
    end

    it 'lists conflicts separately and flags locked fields with [LOCKED]' do
      locked = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'check_content', from: 'A', to: 'B', resolution: :locked_conflict, locked: true, reason: ''
      )
      regular = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'fixtext', from: 'A', to: 'B', resolution: :conflict, locked: false, reason: ''
      )
      plan.add_field_changes('V-1', [locked, regular])

      out = formatter.render
      expect(out).to match(/Conflicts: 2 field/)
      expect(out).to include('[LOCKED]')
      expect(out).to include('check_content')
      expect(out).to include('fixtext')
    end

    it 'prints "(none)" markers when sections are empty' do
      out = formatter.render
      expect(out).to include('Auto-merged: (none)')
      expect(out).to include('Conflicts: (none)')
    end

    it 'truncates long from/to values to keep the report scannable' do
      change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'fixtext', from: 'x' * 200, to: 'y' * 200, resolution: :auto_theirs, locked: false, reason: ''
      )
      plan.add_field_changes('V-1', [change])

      line = formatter.render.lines.find { |l| l.include?('fixtext') }
      expect(line).to include('...')
    end
  end

  describe '#exit_code' do
    it 'is 0 when there are no conflicts' do
      expect(formatter.exit_code).to eq(0)
    end

    it 'is 1 when any conflict is present' do
      change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'fixtext', from: 'A', to: 'B', resolution: :conflict, locked: false, reason: ''
      )
      plan.add_field_changes('V-1', [change])

      expect(formatter.exit_code).to eq(1)
    end

    it 'is 1 when a locked-field conflict is present' do
      change = Import::JsonArchive::Merge::RuleFieldDiffer::FieldChange.new(
        field: 'title', from: 'A', to: 'B', resolution: :locked_conflict, locked: true, reason: ''
      )
      plan.add_field_changes('V-1', [change])

      expect(formatter.exit_code).to eq(1)
    end
  end

  describe '#render (review collisions section)' do
    it 'renders a "Review collisions" section when present' do
      plan.add_review_collisions([
                                   { key: 'rule-V-1::same-text::2026-06-08T12:00:00Z', members: %w[r1 r2] },
                                   { key: 'rule-V-2::other::2026-06-08T12:00:01Z', members: %w[r3 r4 r5] }
                                 ])

      out = formatter.render

      expect(out).to include('Review collisions: 2 degenerate group(s)')
      expect(out).to include('members=2')
      expect(out).to include('members=3')
    end

    it 'omits the section when collisions list is empty' do
      expect(formatter.render).not_to include('Review collisions:')
    end
  end
end
