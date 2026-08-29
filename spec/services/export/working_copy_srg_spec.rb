# frozen_string_literal: true

require 'rails_helper'

##
# SRG components get the same tabular export as STIG components. The kind seam
# (Export::Base reads component.requirements when the mode supports_srg_kind?)
# lets working_copy serve an SRG component's authored requirements; ExportableRule
# emits the SrgRule's own content in the authored columns and blanks the
# source-reference / satisfies / InSpec columns, which have no SRG meaning.
RSpec.describe 'Export::Base working_copy for SRG components' do
  let(:srg_component) do
    create(:component, :skip_rules, document_type: 'srg', prefix: 'ABCD-00')
  end

  let!(:requirement) do
    create(:srg_rule, :authored,
           component: srg_component,
           title: 'Authored SRG requirement one',
           status: 'Applicable',
           rule_severity: 'medium')
  end

  it 'exports an SRG component as a working-copy CSV without raising' do
    result = described_class_export(:csv)
    expect(result.data).to include('Authored SRG requirement one')
  end

  it 'exports an SRG component as a working-copy Excel without raising' do
    result = described_class_export(:excel)
    expect(result.data).to be_present
    expect(result.content_type).to match(/spreadsheet|excel|officedocument/i)
  end

  def described_class_export(format)
    Export::Base.new(exportable: srg_component, mode: :working_copy, format: format).call
  end
end
