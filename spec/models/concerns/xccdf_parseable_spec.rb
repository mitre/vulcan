# frozen_string_literal: true

require 'rails_helper'

RSpec.describe XccdfParseable, type: :concern do
  # Create a minimal test model to include the concern
  let(:test_class) do
    Class.new do
      include XccdfParseable

      attr_accessor :xml

      def initialize(xml)
        @xml = xml
      end
    end
  end

  let(:sample_xml) do
    Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read
  end

  let(:instance) { test_class.new(sample_xml) }

  describe '#parsed_benchmark' do
    context 'when called for the first time' do
      it 'parses the XML and returns a benchmark' do
        expect(Xccdf::Benchmark).to receive(:parse).with(sample_xml).once.and_call_original
        result = instance.parsed_benchmark
        expect(result).to be_a(Xccdf::Benchmark)
      end

      it 'returns a valid benchmark with expected attributes' do
        benchmark = instance.parsed_benchmark
        expect(benchmark.id).not_to be_nil
        expect(benchmark.title).not_to be_empty
        expect(benchmark.version).not_to be_nil
      end
    end

    context 'when called multiple times' do
      it 'memoizes the result and does not re-parse' do
        expect(Xccdf::Benchmark).to receive(:parse).once.and_call_original

        first_call = instance.parsed_benchmark
        second_call = instance.parsed_benchmark
        third_call = instance.parsed_benchmark

        expect(first_call).to be(second_call) # Same object reference
        expect(second_call).to be(third_call)
      end

      it 'returns the same benchmark object each time' do
        benchmark1 = instance.parsed_benchmark
        benchmark2 = instance.parsed_benchmark

        expect(benchmark1.object_id).to eq(benchmark2.object_id)
      end
    end

    context 'when xml is nil' do
      let(:instance) { test_class.new(nil) }

      it 'passes nil to Xccdf::Benchmark.parse' do
        expect(Xccdf::Benchmark).to receive(:parse).with(nil)
        instance.parsed_benchmark
      end
    end

    context 'when xml is empty string' do
      let(:instance) { test_class.new('') }

      it 'passes empty string to Xccdf::Benchmark.parse' do
        expect(Xccdf::Benchmark).to receive(:parse).with('')
        instance.parsed_benchmark
      end
    end
  end

  describe '#parsed_benchmark=' do
    it 'allows setting the parsed_benchmark directly' do
      fake_benchmark = double('Benchmark')
      instance.parsed_benchmark = fake_benchmark

      expect(instance.parsed_benchmark).to eq(fake_benchmark)
    end

    it 'bypasses parsing when set directly' do
      fake_benchmark = double('Benchmark')
      expect(Xccdf::Benchmark).not_to receive(:parse)

      instance.parsed_benchmark = fake_benchmark
      expect(instance.parsed_benchmark).to eq(fake_benchmark)
    end

    it 'can be used to pre-set a benchmark for testing' do
      # This is useful for test contexts where we want to inject a parsed benchmark
      # without triggering the actual XML parsing
      mock_benchmark = instance_double(Xccdf::Benchmark,
                                       id: 'test-id',
                                       title: ['Test Title'],
                                       version: double(version: '1'))

      instance.parsed_benchmark = mock_benchmark
      expect(instance.parsed_benchmark.id).to eq('test-id')
    end
  end

  # Integration tests for models that will use the concern
  describe 'integration with real models' do
    # Component model now includes the concern
    context 'Component model' do
      let(:component) { build(:component) }

      it 'includes the concern' do
        expect(Component.ancestors).to include(XccdfParseable)
      end

      it 'responds to parsed_benchmark' do
        expect(component).to respond_to(:parsed_benchmark)
      end

      it 'responds to parsed_benchmark=' do
        expect(component).to respond_to(:parsed_benchmark=)
      end
    end

    # STIG model now includes the concern
    context 'STIG model' do
      let(:stig) { build(:stig) }

      it 'includes the concern' do
        expect(Stig.ancestors).to include(XccdfParseable)
      end

      it 'responds to parsed_benchmark' do
        expect(stig).to respond_to(:parsed_benchmark)
      end

      it 'has the parsed_benchmark= writer' do
        expect(stig).to respond_to(:parsed_benchmark=)
      end
    end

    # SecurityRequirementsGuide now includes the concern
    context 'SecurityRequirementsGuide model' do
      let(:srg) { build(:security_requirements_guide) }

      it 'includes the concern' do
        expect(SecurityRequirementsGuide.ancestors).to include(XccdfParseable)
      end

      it 'responds to parsed_benchmark' do
        expect(srg).to respond_to(:parsed_benchmark)
      end

      it 'has the parsed_benchmark= writer' do
        expect(srg).to respond_to(:parsed_benchmark=)
      end
    end
  end

  describe 'performance characteristics' do
    it 'caches the parsed result to avoid re-parsing overhead' do
      # First call should trigger parsing
      start_time = Time.current
      instance.parsed_benchmark
      first_duration = Time.current - start_time

      # Second call should be much faster (cached)
      start_time = Time.current
      instance.parsed_benchmark
      second_duration = Time.current - start_time

      # Cached call should be significantly faster (at least 10x)
      expect(second_duration).to be < (first_duration / 10)
    end
  end

  describe 'memory management' do
    it 'allows the cache to be reset by setting to nil' do
      instance.parsed_benchmark # Populate cache
      instance.parsed_benchmark = nil

      expect(Xccdf::Benchmark).to receive(:parse).once
      instance.parsed_benchmark # Should re-parse
    end

    it 'allows replacing cached benchmark with a new one' do
      original_benchmark = instance.parsed_benchmark
      new_benchmark = double('New Benchmark')

      instance.parsed_benchmark = new_benchmark
      expect(instance.parsed_benchmark).to eq(new_benchmark)
      expect(instance.parsed_benchmark).not_to eq(original_benchmark)
    end
  end
end
