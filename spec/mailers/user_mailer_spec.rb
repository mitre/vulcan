# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS (review-workflow mail, kind-shared by design):
# 1. The request_review / approve / revoke_review_request /
#    request_changes family renders for BOTH document kinds — the
#    review-request workflow lives on base_rules, so an authored SRG
#    requirement must mail exactly like a STIG requirement.
# 2. The approve-family recipient is the user who requested the review,
#    found from the requirement row the mailer already holds — never by
#    re-fetching through the Rule (STIG) subclass, which returns nil for
#    an authored SrgRule and crashes the mail.
RSpec.describe UserMailer do
  it 'does not override ApplicationMailer default from address' do
    from_lines = grep_config('app/mailers/user_mailer.rb', /default\s+from:/)

    expect(from_lines).to be_empty,
                          "UserMailer should not override `default from:` — inherit from ApplicationMailer:\n" \
                          "#{from_lines.map(&:strip).join("\n")}"
  end

  it 'inherits ApplicationMailer from address' do
    # UserMailer should not define its own :from — it should inherit from ApplicationMailer.
    own_defaults = UserMailer.instance_variable_get(:@_default_mail_params) || {}
    expect(own_defaults).not_to have_key(:from),
                                'UserMailer should not have its own default :from (inherits from ApplicationMailer)'
  end

  describe '#review_action' do
    let_it_be(:project_admin) { create(:user) }
    let_it_be(:requestor) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:core_srg) do
      create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-MAILER', version: 'V1R1')
    end
    let_it_be(:srg_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      based_on: core_srg, prefix: 'RMLR-00')
    end
    let_it_be(:stig_component) { create(:component, :skip_rules, project: project, prefix: 'MLST-00') }
    let_it_be(:admin_membership) do
      Membership.create!(user: project_admin, membership: project, role: 'admin')
    end

    context 'with an authored SRG requirement' do
      let_it_be(:srg_requirement) do
        create(:srg_rule, :authored, component: srg_component, rule_id: '920001')
      end

      it 'renders and addresses the request_review mail' do
        mail = described_class.review_action('request_review', requestor, srg_component.id,
                                             'Please review', srg_requirement)

        expect(mail.subject).to eq('Review Requested - RMLR-00-920001')
        expect(mail.to).to eq([project_admin.email])
        expect(mail.cc).to eq([requestor.email])
        # The link deep-links to the requirement — a literal path slash,
        # never an encoded %2F (which loses the stig_id route param).
        expect(mail.body.encoded).to include("/components/#{srg_component.id}/RMLR-00-920001")
      end

      it 'addresses the approve mail to the user who requested the review' do
        # SrgRule reviews ride the polymorphic commentable (the rule
        # association is legacy STIG-typed); rule_id is dual-written.
        Membership.find_or_create_by!(user: requestor, membership: project) { |m| m.role = 'author' }
        review = create(:review, rule: nil, commentable: srg_requirement,
                                 user: requestor, action: 'request_review')
        expect(review.rule_id).to eq(srg_requirement.id)

        mail = described_class.review_action('approve', project_admin, srg_component.id,
                                             'Looks good', srg_requirement)

        expect(mail.subject).to eq('Review Approved - RMLR-00-920001')
        expect(mail.to).to eq([requestor.email])
        expect(mail.body.encoded).to include("Hi #{requestor.name},")
      end

      it 'addresses the revoke mail to the user who requested the review' do
        Membership.find_or_create_by!(user: requestor, membership: project) { |m| m.role = 'author' }
        create(:review, rule: nil, commentable: srg_requirement,
                        user: requestor, action: 'request_review')

        mail = described_class.review_action('revoke_review_request', requestor, srg_component.id,
                                             'Withdrawing', srg_requirement)

        expect(mail.subject).to eq('Review Revoked - RMLR-00-920001')
        expect(mail.to).to eq([requestor.email])
      end
    end

    context 'with a STIG requirement (regression pin)' do
      let_it_be(:stig_requirement) do
        create(:rule, component: stig_component, rule_id: '920002')
      end

      it 'renders and addresses the request_review mail' do
        mail = described_class.review_action('request_review', requestor, stig_component.id,
                                             'Please review', stig_requirement)

        expect(mail.subject).to eq('Review Requested - MLST-00-920002')
        expect(mail.to).to eq([project_admin.email])
        expect(mail.cc).to eq([requestor.email])
        expect(mail.body.encoded).to include("/components/#{stig_component.id}/MLST-00-920002")
      end

      it 'addresses the approve mail to the user who requested the review' do
        create(:review, rule: stig_requirement, user: requestor, action: 'request_review')

        mail = described_class.review_action('approve', project_admin, stig_component.id,
                                             'Looks good', stig_requirement)

        expect(mail.subject).to eq('Review Approved - MLST-00-920002')
        expect(mail.to).to eq([requestor.email])
      end
    end
  end
end
