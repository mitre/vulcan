# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SrgRuleBlueprint do
  before { Rails.application.reload_routes! }

  let(:srg) { SecurityRequirementsGuide.first || create(:security_requirements_guide) }
  let(:srg_rule) { srg.srg_rules.first }

  it 'includes the id field so the BenchmarkViewer can track selected rule' do
    json = JSON.parse(described_class.render(srg_rule))
    expect(json).to have_key('id')
    expect(json['id']).to eq(srg_rule.id)
  end
end
