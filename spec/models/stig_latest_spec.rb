# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stig, '.latest_versions' do
  let_it_be(:rhel_v1) do
    create(:stig, :skip_rules, title: 'RHEL 9 STIG', stig_id: 'RHEL_9_STIG', version: 'V1R0')
  end
  let_it_be(:rhel_v2) do
    create(:stig, :skip_rules, title: 'RHEL 9 STIG', stig_id: 'RHEL_9_STIG', version: 'V2R7')
  end
  let_it_be(:rhel_v10) do
    create(:stig, :skip_rules, title: 'RHEL 9 STIG', stig_id: 'RHEL_9_STIG', version: 'V10R3')
  end

  let_it_be(:win_v3) do
    create(:stig, :skip_rules, title: 'Windows Server 2025 STIG', stig_id: 'MS_Windows_Server_2025_STIG', version: 'V3R1')
  end

  it 'returns only the highest-versioned STIG per title' do
    results = described_class.latest_versions
    rhel = results.find { |r| r.title == 'RHEL 9 STIG' }
    expect(rhel.version).to eq('V10R3')
  end

  it 'returns an ActiveRecord::Relation (chainable)' do
    expect(described_class.latest_versions).to be_a(ActiveRecord::Relation)
  end

  it 'includes single-version families' do
    results = described_class.latest_versions
    win = results.find { |r| r.title == 'Windows Server 2025 STIG' }
    expect(win.version).to eq('V3R1')
  end
end
