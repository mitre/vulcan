# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  before do
    Rails.application.reload_routes!
  end

  describe '#base_navigation' do
    subject(:navigation) { helper.base_navigation }

    it 'links the four primary sections' do
      expect(navigation.pluck(:link)).to include('/projects', '/components', '/stigs', '/srgs')
    end

    it 'links the DISA Process Guide directly to the vendor STIG process guide page' do
      resources = navigation.find { |item| item[:name] == 'Resources' }
      guide = resources[:children].find { |child| child[:name] == 'DISA Process Guide' }
      expect(guide[:link]).to eq('/disa-guide/vendor-stig-process-guide')
    end
  end
end
