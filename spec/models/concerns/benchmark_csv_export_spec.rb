# frozen_string_literal: true

require 'rails_helper'
require 'csv'

# rubocop:disable RSpec/IndexedLet, RSpec/VerifiedDoubleReference
RSpec.describe BenchmarkCsvExport do
  # REQUIREMENTS:
  # 1. Provides csv_export method with configurable columns
  # 2. Uses default columns from ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS
  # 3. Supports header overrides (e.g., "STIG ID" → "SRG ID" for SRG context)
  # 4. Orders rules by version, rule_id
  # 5. Eager loads disa_rule_descriptions and checks associations
  # 6. Calls rules_association method (abstract - each model implements)
  # 7. Uses rule.csv_value_for(key) to extract values

  # Create a minimal test class that includes the concern
  let(:test_class) do
    Class.new do
      include BenchmarkCsvExport

      attr_reader :rules

      def initialize(rules)
        @rules = rules
      end

      def rules_association
        rules
      end
    end
  end

  let(:rule1) do
    instance_double('Rule',
                    csv_value_for: nil)
  end

  let(:rule2) do
    instance_double('Rule',
                    csv_value_for: nil)
  end

  let(:rules_relation) do
    instance_double('ActiveRecord::Relation')
  end

  let(:ordered_relation) do
    [rule1, rule2]
  end

  let(:benchmark) { test_class.new(rules_relation) }

  before do
    # Stub the query chain: eager_load(:disa_rule_descriptions, :checks).order(:version, :rule_id)
    allow(rules_relation).to receive(:eager_load)
      .with(:disa_rule_descriptions, :checks)
      .and_return(rules_relation)
    allow(rules_relation).to receive(:order)
      .with(:version, :rule_id)
      .and_return(ordered_relation)

    # Stub csv_value_for responses for default columns
    ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS.each do |key|
      allow(rule1).to receive(:csv_value_for).with(key).and_return("rule1_#{key}")
      allow(rule2).to receive(:csv_value_for).with(key).and_return("rule2_#{key}")
    end
  end

  describe '#csv_export' do
    context 'with default columns' do
      it 'generates valid CSV' do
        csv_string = benchmark.csv_export
        csv = CSV.parse(csv_string, headers: true)
        expect(csv).to be_a(CSV::Table)
      end

      it 'has correct number of data rows' do
        csv = CSV.parse(benchmark.csv_export, headers: true)
        expect(csv.size).to eq(2)
      end

      it 'includes all default column headers' do
        csv = CSV.parse(benchmark.csv_export, headers: true)
        expected_headers = ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS.map do |key|
          ExportConstants::BENCHMARK_CSV_COLUMNS[key][:header]
        end
        expect(csv.headers).to eq(expected_headers)
      end

      it 'contains correct rule data' do
        csv = CSV.parse(benchmark.csv_export, headers: true)
        first_row = csv.first
        # Check first column (rule_id)
        first_column_key = ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS.first
        first_column_header = ExportConstants::BENCHMARK_CSV_COLUMNS[first_column_key][:header]
        expect(first_row[first_column_header]).to eq('rule1_rule_id')
      end

      it 'eager loads disa_rule_descriptions and checks' do
        benchmark.csv_export
        expect(rules_relation).to have_received(:eager_load).with(:disa_rule_descriptions, :checks)
      end

      it 'orders rules by version then rule_id' do
        benchmark.csv_export
        expect(rules_relation).to have_received(:order).with(:version, :rule_id)
      end

      it 'calls csv_value_for on each rule for each column' do
        benchmark.csv_export
        ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS.each do |key|
          expect(rule1).to have_received(:csv_value_for).with(key)
          expect(rule2).to have_received(:csv_value_for).with(key)
        end
      end
    end

    context 'with column selection' do
      it 'includes only selected columns' do
        csv = CSV.parse(benchmark.csv_export(columns: %i[rule_id version rule_severity]), headers: true)
        expect(csv.headers).to eq(['Rule ID', 'STIG ID', 'Severity'])
      end

      it 'preserves column order from selection' do
        csv = CSV.parse(benchmark.csv_export(columns: %i[title rule_id rule_severity]), headers: true)
        expect(csv.headers).to eq(['Title', 'Rule ID', 'Severity'])
      end

      it 'calls csv_value_for only for selected columns' do
        # Stub only the selected columns
        %i[rule_id title].each do |key|
          allow(rule1).to receive(:csv_value_for).with(key).and_return("rule1_#{key}")
          allow(rule2).to receive(:csv_value_for).with(key).and_return("rule2_#{key}")
        end

        benchmark.csv_export(columns: %i[rule_id title])

        expect(rule1).to have_received(:csv_value_for).with(:rule_id).once
        expect(rule1).to have_received(:csv_value_for).with(:title).once
        expect(rule1).not_to have_received(:csv_value_for).with(:version)
      end
    end

    context 'with header overrides' do
      it 'applies custom headers when provided' do
        csv = CSV.parse(
          benchmark.csv_export(
            columns: %i[rule_id version],
            header_overrides: { version: 'SRG ID' }
          ),
          headers: true
        )
        expect(csv.headers).to eq(['Rule ID', 'SRG ID'])
      end

      it 'uses default header when no override exists' do
        csv = CSV.parse(
          benchmark.csv_export(
            columns: %i[rule_id version],
            header_overrides: { title: 'Custom Title' }
          ),
          headers: true
        )
        expect(csv.headers).to eq(['Rule ID', 'STIG ID'])
      end

      it 'handles multiple header overrides' do
        csv = CSV.parse(
          benchmark.csv_export(
            columns: %i[rule_id version title],
            header_overrides: { version: 'SRG ID', title: 'Requirement' }
          ),
          headers: true
        )
        expect(csv.headers).to eq(['Rule ID', 'SRG ID', 'Requirement'])
      end
    end

    context 'with default columns parameter' do
      # Create test class with custom default columns
      let(:custom_test_class) do
        Class.new do
          include BenchmarkCsvExport

          attr_reader :rules

          def initialize(rules)
            @rules = rules
          end

          def rules_association
            rules
          end

          def default_columns
            %i[rule_id version]
          end
        end
      end

      let(:custom_benchmark) { custom_test_class.new(rules_relation) }

      before do
        %i[rule_id version].each do |key|
          allow(rule1).to receive(:csv_value_for).with(key).and_return("rule1_#{key}")
          allow(rule2).to receive(:csv_value_for).with(key).and_return("rule2_#{key}")
        end
      end

      it 'uses default_columns method when defined' do
        csv = CSV.parse(custom_benchmark.csv_export, headers: true)
        expect(csv.headers).to eq(['Rule ID', 'STIG ID'])
      end

      it 'falls back to BENCHMARK_CSV_DEFAULT_COLUMNS when default_columns not defined' do
        csv = CSV.parse(benchmark.csv_export, headers: true)
        expected_headers = ExportConstants::BENCHMARK_CSV_DEFAULT_COLUMNS.map do |key|
          ExportConstants::BENCHMARK_CSV_COLUMNS[key][:header]
        end
        expect(csv.headers).to eq(expected_headers)
      end
    end

    context 'error handling' do
      it 'raises NameError when rules_association not implemented' do
        broken_class = Class.new do
          include BenchmarkCsvExport
        end
        broken_instance = broken_class.new

        expect { broken_instance.csv_export }.to raise_error(NameError, /rules_association/)
      end
    end
  end
end
# rubocop:enable RSpec/IndexedLet, RSpec/VerifiedDoubleReference
