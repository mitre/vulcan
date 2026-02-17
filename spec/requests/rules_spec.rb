# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Rules', type: :request do
  let(:user) { create(:user) }
  let(:component) { create(:component) }
  let(:project) { component.project }

  before do
    Rails.application.reload_routes!
    Membership.create!(user: user, membership: project, role: 'author')
  end

  describe 'PUT /rules/:id' do
    let(:rule) do
      component.rules.first.tap do |r|
        r.update!(status: 'Applicable - Configurable')
      end
    end

    let(:check) do
      rule.checks.first.tap do |c|
        c.update!(content: 'Original check text')
      end
    end

    it 'updates check content' do
      sign_in user

      original_content = check.content
      new_content = 'Updated check text'

      put "/rules/#{rule.id}", params: {
        rule: {
          status: rule.status,
          checks_attributes: [
            { id: check.id, content: new_content }
          ]
        }
      }, as: :json

      expect(response).to have_http_status(:ok)

      check.reload
      expect(check.content).to eq(new_content)
      expect(check.content).not_to eq(original_content)
    end
  end
end
