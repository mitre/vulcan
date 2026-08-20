# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS (Slack review-notification fields, kind-shared by design):
# 1. review_notification_fields renders for BOTH document kinds — the
#    review workflow lives on base_rules, so an authored SRG requirement
#    must produce the same field set as a STIG requirement (never a
#    crash from type-matching only the Rule subclass).
# 2. The Control field deep-links to the requirement exactly once:
#    <.../components/:id/PREFIX-RULEID|PREFIX-RULEID> — never a
#    duplicated path segment.
RSpec.describe NotificationFieldsHelper do
  let_it_be(:acting_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-SLACK', version: 'V1R1')
  end
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    based_on: core_srg, prefix: 'SLCK-00')
  end
  let_it_be(:stig_component) { create(:component, :skip_rules, project: project, prefix: 'SLST-00') }
  let_it_be(:srg_requirement) do
    create(:srg_rule, :authored, component: srg_component, rule_id: '930001')
  end
  let_it_be(:stig_requirement) { create(:rule, component: stig_component, rule_id: '930002') }

  let(:notifier) do
    user = acting_user
    Class.new do
      include NotificationFieldsHelper

      define_method(:current_user) { user }

      def default_url_options
        { host: 'test.host' }
      end
    end.new
  end

  describe '#review_notification_fields' do
    it 'builds the field set for an authored SRG requirement' do
      fields = notifier.review_notification_fields('request_review', srg_requirement, 'Please review')

      expect(fields[:generate_control_label][:value])
        .to eq("<http://test.host/components/#{srg_component.id}/SLCK-00-930001|SLCK-00-930001>")
      expect(fields[:generate_component_label][:value])
        .to eq("<http://test.host/components/#{srg_component.id}|#{srg_component.name}>")
      expect(fields[:generate_project_label][:value])
        .to eq("<http://test.host/projects/#{project.id}|#{project.name}>")
      expect(fields[:generate_comment_label][:value]).to eq('Please review')
    end

    it 'deep-links the Control field exactly once for a STIG requirement' do
      fields = notifier.review_notification_fields('approve', stig_requirement, 'Looks good')

      expect(fields[:generate_control_label][:value])
        .to eq("<http://test.host/components/#{stig_component.id}/SLST-00-930002|SLST-00-930002>")
    end
  end
end
