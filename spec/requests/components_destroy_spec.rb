# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component destruction' do
  include_context 'components request base setup'

  describe 'DELETE /components/:id' do
    it 'destroys component and all dependent records' do
      doomed = create(:component, project: project)
      rule_ids = doomed.rules.pluck(:id)

      delete "/components/#{doomed.id}",
             headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      expect(Component.find_by(id: doomed.id)).to be_nil
      expect(Rule.unscoped.where(id: rule_ids).count).to eq(0)
    end
  end
end
