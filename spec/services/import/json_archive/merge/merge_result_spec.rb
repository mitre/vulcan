# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::Merge::MergeResult, type: :service do
  let(:result) { described_class.new }

  describe 'inheritance' do
    it 'extends Import::Result so callers can treat it as one' do
      expect(result).to be_an(Import::Result)
    end

    it 'starts as a successful result with no errors / warnings' do
      expect(result.success?).to be(true)
      expect(result.errors).to be_empty
      expect(result.warnings).to be_empty
    end
  end

  describe '#add_structured_error' do
    it 'captures entity_type / entity_key / step / message' do
      result.add_structured_error(entity_type: :rule, entity_key: 'V-123', step: :diff, message: 'oops')

      err = result.structured_errors.first
      expect(err.entity_type).to eq(:rule)
      expect(err.entity_key).to eq('V-123')
      expect(err.step).to eq(:diff)
      expect(err.message).to eq('oops')
    end

    it 'flattens to a formatted Import::Result#errors string' do
      result.add_structured_error(entity_type: :rule, entity_key: 'V-1', step: :diff, message: 'boom')

      expect(result.errors).to include('[rule/V-1 @ diff] boom')
    end

    it 'flips success? to false' do
      expect { result.add_structured_error(entity_type: :rule, entity_key: 'V-1', step: :diff, message: 'x') }
        .to change(result, :success?).from(true).to(false)
    end
  end

  describe '#attach_plan' do
    let(:plan) do
      Import::JsonArchive::Merge::MergePlan.new(component_id: 1, strategy: 'default', manifest: {}).tap do |p|
        p.add_rule_partition(matched: [1, 2], only_ours: [3], only_theirs: [])
      end
    end

    it 'stores the plan reference for downstream callers' do
      result.attach_plan(plan)
      expect(result.plan).to be(plan)
    end

    it 'folds plan summary into the result summary' do
      result.attach_plan(plan)
      expect(result.summary['rules']).to eq('matched' => 2, 'only_ours' => 1, 'only_theirs' => 0)
    end
  end

  describe 'StructuredError#to_h' do
    it 'returns string-keyed/string-valued hash (resolution-log compatible)' do
      err = described_class::StructuredError.new(entity_type: :rule, entity_key: 'V-1', step: :diff, message: 'x')

      expect(err.to_h).to eq(
        'entity_type' => 'rule', 'entity_key' => 'V-1', 'step' => 'diff', 'message' => 'x'
      )
      expect(err.to_h.values).to all(be_a(String))
    end
  end
end
