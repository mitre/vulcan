# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stig factory deadlock prevention', type: :model do
  it 'check factory creates without triggering full STIG import' do
    expect { create(:check) }.not_to raise_error
  end

  it 'stig_rule factory creates without triggering full STIG import' do
    expect { create(:stig_rule) }.not_to raise_error
  end

  it 'stig factory with :skip_rules does not import stig_rules' do
    stig = create(:stig, :skip_rules)
    expect(stig).to be_persisted
    expect(stig.stig_rules.count).to eq(0)
  end

  it 'stig factory without :skip_rules imports stig_rules' do
    stig = create(:stig)
    expect(stig).to be_persisted
    expect(stig.stig_rules.count).to be > 0
  end
end
