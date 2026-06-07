# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecurityRequirementsGuide, '.latest_versions' do
  let_it_be(:srg_v2) do
    create(:security_requirements_guide, title: 'GPOS SRG', srg_id: 'GPOS_SRG', version: 'V2R4')
  end
  let_it_be(:srg_v3) do
    create(:security_requirements_guide, title: 'GPOS SRG', srg_id: 'GPOS_SRG', version: 'V3R3')
  end
  let_it_be(:srg_v10) do
    create(:security_requirements_guide, title: 'GPOS SRG', srg_id: 'GPOS_SRG', version: 'V10R1')
  end

  let_it_be(:web_v1) do
    create(:security_requirements_guide, title: 'Web Server SRG', srg_id: 'Web_Server_SRG', version: 'V1R5')
  end
  let_it_be(:web_v2) do
    create(:security_requirements_guide, title: 'Web Server SRG', srg_id: 'Web_Server_SRG', version: 'V2R10')
  end
  let_it_be(:web_v2r9) do
    create(:security_requirements_guide, title: 'Web Server SRG', srg_id: 'Web_Server_SRG', version: 'V2R9')
  end

  it 'returns only the highest-versioned SRG per title' do
    results = described_class.latest_versions
    titles = results.pluck(:title)
    expect(titles).to contain_exactly('GPOS SRG', 'Web Server SRG')
  end

  it 'ranks V10R1 above V3R3 (numeric, not string comparison)' do
    results = described_class.latest_versions
    gpos = results.find { |r| r.title == 'GPOS SRG' }
    expect(gpos.version).to eq('V10R1')
  end

  it 'ranks V2R10 above V2R9 (numeric minor comparison)' do
    results = described_class.latest_versions
    web = results.find { |r| r.title == 'Web Server SRG' }
    expect(web.version).to eq('V2R10')
  end

  it 'returns an ActiveRecord::Relation (chainable)' do
    expect(described_class.latest_versions).to be_a(ActiveRecord::Relation)
  end

  it 'works with a single version per title' do
    solo = create(:security_requirements_guide, title: 'Solo SRG', srg_id: 'Solo_SRG', version: 'V1R1')
    results = described_class.latest_versions
    expect(results.find { |r| r.title == 'Solo SRG' }.id).to eq(solo.id)
  end

  it 'handles non-standard version strings gracefully' do
    odd = create(:security_requirements_guide, title: 'Odd SRG', srg_id: 'Odd_SRG', version: 'Draft')
    expect { described_class.latest_versions.to_a }.not_to raise_error
    result = described_class.latest_versions.find { |r| r.title == 'Odd SRG' }
    expect(result.id).to eq(odd.id)
  end
end
