# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Stig, type: :model do
  let(:stig) { create(:stig) }

  context 'validation' do
    it 'validates presence of stig_id, title, version, and xml' do
      expect(stig.stig_id).to be_present
      expect(stig.title).to be_present
      expect(stig.name).to be_present
      expect(stig.version).to be_present
      expect(stig.xml).to be_present
    end

    it 'validates uniqueness of stig_id scoped to version' do
      stig2 = stig.dup
      stig2.valid?
      expect(stig2.errors.full_messages).to include('Stig ID has already been taken')
    end
  end
end
