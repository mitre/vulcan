# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VuePropsHelper do
  let(:user) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  describe '#common_vue_props' do
    subject(:props) { helper.common_vue_props }

    it 'returns a hash with v-bind:-prefixed keys' do
      expect(props.keys).to all(start_with('v-bind:'))
    end

    it 'includes current_user_id as JSON integer' do
      expect(props['v-bind:current_user_id']).to eq(user.id.to_json)
    end

    it 'includes statuses from RuleConstants' do
      expect(props['v-bind:statuses']).to eq(RuleConstants::STATUSES.to_json)
    end

    it 'includes available_roles from ProjectMemberConstants' do
      expect(props['v-bind:available_roles']).to eq(ProjectMemberConstants::PROJECT_MEMBER_ROLES.to_json)
    end

    it 'returns exactly 3 props' do
      expect(props.size).to eq(3)
    end
  end
end
