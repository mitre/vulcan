# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS (one-call requirement creation, kind-shared by design):
# 1. POST /components/:id/rules creates a requirement WITH content in one
#    call — the update-equivalent surface persists at creation; provided
#    values win over template defaults, and provided nested attributes
#    replace the built-in defaults (never append beside them).
# 2. The kind seam routes the class: a stig component creates a Rule, an
#    srg component creates an authored SrgRule — never a class-Rule row
#    on an srg component (the corruption gate holds structurally).
# 3. Requirement numbering uses the one kind-agnostic primitive:
#    tombstoned numbers are never reissued (full unique index on
#    rule_id + component_id).
# 4. Blank-create and duplicate behave as today for STIG components;
#    duplication copies through the per-class mechanic (amoeba for Rule,
#    dup_with_nested_records for SrgRule — an SrgRule copy STAYS an
#    SrgRule).
# 5. Authorization is symmetric across kinds: blank/content create is a
#    project-admin action, duplicate is an author action.
RSpec.describe 'Rules creation' do
  let_it_be(:admin) { create(:user) }
  let_it_be(:author) { create(:user) }
  let_it_be(:viewer) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:stig_srg) do
    create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-STIG-CREATE', version: 'V1R1')
  end
  # The blank-create seed template: the SRG's CCI-000366 baseline row.
  let_it_be(:template_row) do
    create(:srg_rule, security_requirements_guide: stig_srg, rule_id: '000366',
                      rule_severity: 'medium', title: 'Baseline configuration requirement')
  end
  let_it_be(:stig_component) do
    create(:component, :skip_rules, project: project, based_on: stig_srg, prefix: 'CRST-00')
  end
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-CREATE', version: 'V1R1')
  end
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    based_on: core_srg, prefix: 'CRSR-00')
  end

  before_all do
    Membership.create!(user: admin, membership: project, role: 'admin')
    Membership.create!(user: author, membership: project, role: 'author')
    Membership.create!(user: viewer, membership: project, role: 'viewer')
  end

  before do
    Rails.application.reload_routes!
  end

  describe 'STIG component — one-call create with content' do
    before { sign_in admin }

    it 'persists every provided scalar field in one call' do
      post "/components/#{stig_component.id}/rules",
           params: { rule: { duplicate: false, title: 'One-call created control',
                             status: 'Applicable - Configurable',
                             vendor_comments: 'Created with content in one request',
                             rule_severity: 'high', fixtext: 'Configure the thing securely.' } },
           as: :json

      expect(response).to have_http_status(:ok)
      created = Rule.find(response.parsed_body.dig('data', 'id'))
      expect(created.title).to eq('One-call created control')
      expect(created.status).to eq('Applicable - Configurable')
      expect(created.vendor_comments).to eq('Created with content in one request')
      expect(created.rule_severity).to eq('high')
      expect(created.fixtext).to eq('Configure the thing securely.')
    end

    it 'replaces the default nested records with provided ones — never appends beside them' do
      post "/components/#{stig_component.id}/rules",
           params: { rule: { duplicate: false,
                             checks_attributes: [{ system: 'C-1', content: 'Verify the setting.' }],
                             disa_rule_descriptions_attributes: [{ vuln_discussion: 'Provided discussion.' }] } },
           as: :json

      expect(response).to have_http_status(:ok)
      created = Rule.find(response.parsed_body.dig('data', 'id'))
      expect(created.checks.count).to eq(1)
      expect(created.checks.first.content).to eq('Verify the setting.')
      expect(created.disa_rule_descriptions.count).to eq(1)
      expect(created.disa_rule_descriptions.first.vuln_discussion).to eq('Provided discussion.')
    end

    it 'blank create works — NYD status, inherited severity, defaults built' do
      post "/components/#{stig_component.id}/rules", params: { rule: { duplicate: false } }, as: :json

      expect(response).to have_http_status(:ok)
      created = Rule.find(response.parsed_body.dig('data', 'id'))
      expect(created.status).to eq('Not Yet Determined')
      # Severity is INHERITED from the template row — never a fabricated
      # value the model rejects ('unknown' made every blank create 422).
      expect(created.rule_severity).to eq('medium')
      expect(created.srg_rule_id).to eq(template_row.id)
      expect(created.checks.count).to eq(1)
      expect(created.disa_rule_descriptions.count).to eq(1)
      expect(created.rule_id).to eq(format('%06d', stig_component.reload.largest_rule_id))
    end

    it 'answers a clear 422 when the source SRG has no baseline template row' do
      bare_srg = create(:security_requirements_guide, :skip_rules, srg_id: 'SRG-BARE-CREATE', version: 'V1R1')
      bare_component = create(:component, :skip_rules, project: project, based_on: bare_srg, prefix: 'CRBR-00')

      post "/components/#{bare_component.id}/rules", params: { rule: { duplicate: false } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join).to include('baseline')
    end

    context 'with auditing enabled' do
      include_context 'with auditing'

      # One real create audit from audited, attributed to the acting
      # user — never the bulk-shaped System audit (which raised on
      # interactive saves) and never a double audit beside it.
      it 'writes exactly one create audit attributed to the acting user' do
        post "/components/#{stig_component.id}/rules", params: { rule: { duplicate: false } }, as: :json

        expect(response).to have_http_status(:ok)
        created = Rule.find(response.parsed_body.dig('data', 'id'))
        create_audits = created.audits.where(action: 'create')
        expect(create_audits.count).to eq(1)
        expect(create_audits.first.user_id).to eq(admin.id)
        expect(create_audits.first.user_type).to eq('User')
      end
    end

    it 'never reissues a tombstoned number' do
      post "/components/#{stig_component.id}/rules", params: { rule: { duplicate: false } }, as: :json
      first_created = Rule.find(response.parsed_body.dig('data', 'id'))
      first_number = first_created.rule_id.to_i
      first_created.update_columns(deleted_at: Time.current)

      post "/components/#{stig_component.id}/rules", params: { rule: { duplicate: false } }, as: :json

      expect(response).to have_http_status(:ok)
      created = Rule.find(response.parsed_body.dig('data', 'id'))
      expect(created.rule_id.to_i).to eq(first_number + 1)
    end
  end

  describe 'STIG component — duplicate mode (regression pin)' do
    let_it_be(:source_rule) do
      create(:rule, component: stig_component, rule_id: '000900',
                    title: 'Source control', vendor_comments: 'Copy me')
    end

    it 'duplicates with content for an author' do
      sign_in author

      post "/components/#{stig_component.id}/rules",
           params: { rule: { duplicate: true, id: source_rule.id } }, as: :json

      expect(response).to have_http_status(:ok)
      copy = Rule.find(response.parsed_body.dig('data', 'id'))
      expect(copy.id).not_to eq(source_rule.id)
      expect(copy.title).to eq('Source control')
      expect(copy.rule_id).not_to eq('000900')
    end

    it 'answers 404 for a source rule from another component — never a cross-component clone' do
      other_component = create(:component, :skip_rules, project: project,
                                                        based_on: stig_srg, prefix: 'CROT-00')
      foreign_source = create(:rule, component: other_component, rule_id: '000905')
      sign_in author

      expect do
        post "/components/#{stig_component.id}/rules",
             params: { rule: { duplicate: true, id: foreign_source.id } }, as: :json
      end.not_to change(Rule, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'SRG component — one-call authored requirement creation' do
    before { sign_in admin }

    it 'creates an authored SrgRule — never a class-Rule row' do
      post "/components/#{srg_component.id}/rules",
           params: { rule: { duplicate: false, title: 'Net-new authored requirement',
                             status: 'Applicable', fixtext: 'Enforce the requirement.' } },
           as: :json

      expect(response).to have_http_status(:ok)
      created = BaseRule.unscoped.find(response.parsed_body.dig('data', 'id'))
      expect(created.class).to eq(SrgRule)
      expect(created.component_id).to eq(srg_component.id)
      expect(created.security_requirements_guide_id).to be_nil
      expect(created.title).to eq('Net-new authored requirement')
      expect(created.status).to eq('Applicable')
      expect(created.fixtext).to eq('Enforce the requirement.')
      # The corruption gate holds structurally: no Rule rows on the component.
      expect(srg_component.reload.rules.count).to eq(0)
      expect(srg_component.requirements.count).to be >= 1
    end

    it 'assigns the next number from the kind-agnostic sequence' do
      create(:srg_rule, :authored, component: srg_component, rule_id: '000450')

      post "/components/#{srg_component.id}/rules", params: { rule: { duplicate: false } }, as: :json

      expect(response).to have_http_status(:ok)
      created = BaseRule.unscoped.find(response.parsed_body.dig('data', 'id'))
      expect(created.rule_id).to eq('000451')
      expect(created.status).to eq('Not Yet Determined')
    end

    it 'enforces the SRG vocabulary at creation' do
      post "/components/#{srg_component.id}/rules",
           params: { rule: { duplicate: false, status: 'Applicable - Configurable' } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join).to include('is not an acceptable value')
    end

    it 'enforces the Not Applicable justification at creation' do
      post "/components/#{srg_component.id}/rules",
           params: { rule: { duplicate: false, status: 'Not Applicable' } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message'))
        .to include('Status justification is required when the requirement is Not Applicable')
    end

    it 'duplicates an authored requirement as an SrgRule with its content' do
      source = create(:srg_rule, :authored, component: srg_component, rule_id: '000600',
                                            title: 'Authored source', vendor_comments: 'Copy this too')
      sign_in author

      post "/components/#{srg_component.id}/rules",
           params: { rule: { duplicate: true, id: source.id } }, as: :json

      expect(response).to have_http_status(:ok)
      copy = BaseRule.unscoped.find(response.parsed_body.dig('data', 'id'))
      expect(copy.class).to eq(SrgRule)
      expect(copy.title).to eq('Authored source')
      expect(copy.vendor_comments).to eq('Copy this too')
      expect(copy.rule_id).not_to eq('000600')
      expect(copy.security_requirements_guide_id).to be_nil
    end
  end

  describe 'authorization is symmetric across kinds' do
    it 'rejects blank/content create from an author on a stig component' do
      sign_in author

      post "/components/#{stig_component.id}/rules", params: { rule: { duplicate: false } }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects blank/content create from an author on an srg component' do
      sign_in author

      post "/components/#{srg_component.id}/rules", params: { rule: { duplicate: false } }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects duplicate from a viewer' do
      source = create(:rule, component: stig_component, rule_id: '000910')
      sign_in viewer

      post "/components/#{stig_component.id}/rules",
           params: { rule: { duplicate: true, id: source.id } }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
