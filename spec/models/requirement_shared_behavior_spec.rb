# frozen_string_literal: true

require 'rails_helper'

# Locking, review requests, comments, and audit history are ONE machinery
# across requirement kinds — these contexts run the identical example set
# against a STIG Rule and a component-authored SrgRule.
RSpec.describe 'Requirement shared behavior' do
  let_it_be(:admin_user) { create(:user, admin: true) }
  let_it_be(:project) { create(:project) }
  let_it_be(:membership) { Membership.create!(user: admin_user, membership: project, role: 'admin') }

  context 'with a STIG rule' do
    let_it_be(:stig_component) do
      create(:component, :skip_rules, project: project, prefix: 'SHRB-00',
                                      name: 'Shared Behavior STIG', title: 'Shared Behavior STIG')
    end
    let(:requirement) { create(:rule, component: stig_component) }

    it_behaves_like 'a requirement with shared review machinery'
  end

  context 'with an authored SRG requirement' do
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg', prefix: 'SHRS-00',
                                      name: 'Shared Behavior SRG', title: 'Shared Behavior SRG')
    end
    let(:requirement) { create(:srg_rule, :authored, component: srg_component) }

    it_behaves_like 'a requirement with shared review machinery'
  end
end
