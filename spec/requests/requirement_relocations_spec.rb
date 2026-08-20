# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT (relocation proposal API): authors of an SRG component mark
# a requirement for relocation (an open proposal — the source-side offer),
# withdraw it while open, and read the per-SRG backlog. The RECEIVING
# side adjudicates with TARGET-side author rights only (the mark carries
# source consent): accept lands the move; decline requires a rationale,
# is retained, and surfaces to the source author in the backlog. Executed
# records are untouchable through the API. Backlog rows are scoped to
# projects the caller can see.
RSpec.describe 'Requirement relocations' do
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:author) { create(:user) }
  let_it_be(:viewer) { create(:user) }
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RELOCAPI', version: 'V1R1')
  end
  let_it_be(:project) { create(:project) }
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    based_on: core_srg, prefix: 'RAPI-00')
  end
  let_it_be(:author_membership) do
    Membership.create!(user: author, membership: project, role: 'author')
  end
  let_it_be(:viewer_membership) do
    Membership.create!(user: viewer, membership: project, role: 'viewer')
  end

  before do
    Rails.application.reload_routes!
  end

  def authored_row(rule_id)
    create(:srg_rule, :authored, component: srg_component, rule_id: rule_id)
  end

  describe 'POST /rules/:rule_id/relocations (mark)' do
    it 'creates a pending marker for an author' do
      source = authored_row('910001')
      sign_in author

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'CTR' } }

      expect(response).to have_http_status(:ok)
      record = RequirementRelocation.find_by!(source_rule_id: source.id)
      expect(record.target_technology_token).to eq('CTR')
      expect(record.requested_by_id).to eq(author.id)
      expect(record.executed_at).to be_nil
      # DISA display vocabulary — proposed; the destination is an SRG.
      expect(response.parsed_body.dig('toast', 'title')).to eq('Relocation proposed.')
      expect(response.parsed_body.dig('toast', 'message').join).to eq('Proposed for the CTR SRG.')
    end

    it 'rejects a blank abbreviation in user vocabulary — abbreviation, never token' do
      source = authored_row('910012')
      sign_in author

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      message = response.parsed_body.dig('toast', 'message').join
      expect(message).to eq("Destination SRG abbreviation can't be blank")
    end

    it 'rejects a duplicate pending marker with a 422 toast' do
      source = authored_row('910002')
      RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR')
      sign_in author

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'GPOS' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('toast', 'message').join).to match(/open relocation proposal/i)
    end

    it 'forbids a viewer from marking' do
      source = authored_row('910003')
      sign_in viewer

      post "/rules/#{source.id}/relocations",
           params: { requirement_relocation: { target_technology_token: 'CTR' } }

      expect(response).not_to have_http_status(:ok)
      expect(RequirementRelocation.where(source_rule_id: source.id).count).to eq(0)
    end
  end

  describe 'DELETE /requirement_relocations/:id (un-mark)' do
    it 'destroys a pending marker for an author' do
      source = authored_row('910004')
      record = RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR')
      sign_in author

      delete "/requirement_relocations/#{record.id}"

      expect(response).to have_http_status(:ok)
      expect(RequirementRelocation.exists?(record.id)).to be false
    end

    it 'answers 404 for an executed record — immutable through the API' do
      source = authored_row('910005')
      source.update!(deleted_at: Time.current)
      executed = RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR',
                                               executed_at: 1.day.ago)
      sign_in author

      delete "/requirement_relocations/#{executed.id}"

      expect(response).to have_http_status(:not_found)
      expect(RequirementRelocation.exists?(executed.id)).to be true
    end
  end

  describe 'GET /requirement_relocations/destinations (picker options)' do
    it 'serves one row per token — open components win over released, hidden projects excluded' do
      # Released release of the SAME SRG as the open srg_component (RAPI):
      # the open one must win the token row.
      released_rapi = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                      based_on: core_srg, prefix: 'RAPI-00',
                                                      name: 'RAPI prior release', version: 1)
      released_rapi.update_column(:released, true)
      # A released-only token: the queued next-release case.
      released_only = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                      based_on: core_srg, prefix: 'RQUE-00',
                                                      name: 'Queued SRG')
      released_only.update_column(:released, true)
      # A hidden project's SRG component must not be disclosed.
      hidden_project = create(:project)
      create(:component, :skip_rules, project: hidden_project, document_type: 'srg',
                                      based_on: core_srg, prefix: 'RSEC-00', name: 'Hidden SRG')
      # STIG-kind components are never destinations.
      create(:component, :skip_rules, project: project, prefix: 'RSTG-00', name: 'A STIG')
      sign_in author

      get '/requirement_relocations/destinations'

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body
      tokens = rows.pluck('token')
      expect(tokens).to include('RAPI', 'RQUE')
      expect(tokens).not_to include('RSEC', 'RSTG')
      rapi = rows.find { |row| row['token'] == 'RAPI' }
      expect(rapi['released']).to be false
      expect(rapi['name']).to eq(srg_component.name)
      que = rows.find { |row| row['token'] == 'RQUE' }
      expect(que['released']).to be true
      expect(que['name']).to eq('Queued SRG')
    end

    it 'requires authentication' do
      get '/requirement_relocations/destinations'
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /requirement_relocations (per-SRG backlog)' do
    it 'lists pending markers for the token with source identity' do
      source = authored_row('910006')
      RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR',
                                    requested_by: author)
      other = authored_row('910007')
      RequirementRelocation.create!(source_rule: other, target_technology_token: 'GPOS')
      executed_source = authored_row('910008')
      executed_source.update!(deleted_at: Time.current)
      RequirementRelocation.create!(source_rule: executed_source, target_technology_token: 'CTR',
                                    executed_at: 1.day.ago)
      sign_in author

      get '/requirement_relocations', params: { target_technology_token: 'CTR' }

      expect(response).to have_http_status(:ok)
      rows = response.parsed_body
      expect(rows.size).to eq(1)
      expect(rows.first['target_technology_token']).to eq('CTR')
      expect(rows.first['source_displayed_name']).to eq('RAPI-00-910006')
      expect(rows.first['component_id']).to eq(srg_component.id)
      expect(rows.first['requested_by_name']).to eq(author.name)
    end

    it 'excludes markers whose project the caller cannot see' do
      hidden_project = create(:project)
      hidden_component = create(:component, :skip_rules, project: hidden_project,
                                                         document_type: 'srg', based_on: core_srg,
                                                         prefix: 'RHID-00')
      hidden_source = create(:srg_rule, :authored, component: hidden_component, rule_id: '910009')
      RequirementRelocation.create!(source_rule: hidden_source, target_technology_token: 'CTR')
      sign_in author

      get '/requirement_relocations', params: { target_technology_token: 'CTR' }

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.pluck('id')
      expect(RequirementRelocation.find_by(source_rule_id: hidden_source.id).id).not_to be_in(ids)
    end
  end

  describe 'adjudicating a proposal (receiver side)' do
    let_it_be(:target_component) do
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      based_on: core_srg, prefix: 'RTGT-00')
    end
    # The cross-boundary case the workflow exists for: the receiver
    # authors the RECEIVING project only — no membership on the source.
    let_it_be(:receiving_project) { create(:project) }
    let_it_be(:receiving_component) do
      create(:component, :skip_rules, project: receiving_project, document_type: 'srg',
                                      based_on: core_srg, prefix: 'RRCV-00')
    end
    let_it_be(:receiver) { create(:user) }
    let_it_be(:receiver_membership) do
      Membership.create!(user: receiver, membership: receiving_project, role: 'author')
    end

    def open_proposal(rule_id, token: 'RTGT')
      source = authored_row(rule_id)
      RequirementRelocation.create!(source_rule: source, target_technology_token: token)
    end

    describe 'POST /requirement_relocations/:id/dry_run' do
      it 'previews the move with zero writes for a target-side author' do
        record = open_proposal('910010')
        sign_in receiver

        expect do
          post "/requirement_relocations/#{record.id}/dry_run",
               params: { target_component_id: receiving_component.id }
        end.not_to(change { [SrgRule.unscoped.count, record.reload.executed_at] })

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['valid']).to be true
        expect(body['source_displayed_name']).to eq('RAPI-00-910010')
        expect(body['target_component_id']).to eq(receiving_component.id)
      end

      it 'reports validation errors without writing' do
        record = open_proposal('910011')
        stig_target = create(:component, :skip_rules, project: project, prefix: 'RSTG-00')
        sign_in author

        post "/requirement_relocations/#{record.id}/dry_run",
             params: { target_component_id: stig_target.id }

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body['valid']).to be false
        expect(body['errors'].join).to match(/SRG component/)
      end
    end

    describe 'POST /requirement_relocations/:id/accept' do
      it 'lands the move for a TARGET-only author — no source-side membership required' do
        record = open_proposal('910012', token: 'RRCV')
        source_id = record.source_rule_id
        sign_in receiver

        post "/requirement_relocations/#{record.id}/accept",
             params: { target_component_id: receiving_component.id }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig('toast', 'variant')).to eq('success')
        expect(response.parsed_body.dig('toast', 'title')).to eq('Concurred.')
        record.reload
        expect(record.executed_at).to be_present
        expect(record.accepted_by_id).to eq(receiver.id)
        expect(record.target_rule).to have_attributes(component_id: receiving_component.id)
        expect(SrgRule.unscoped.find(source_id).deleted_at).to be_present
        # The landed requirement id rides the toast so the editor can
        # materialize the new row without a page reload.
        expect(response.parsed_body['landed_rule_id']).to eq(record.target_rule_id)
      end

      it 'returns 422 with the executor errors when the move is invalid' do
        record = open_proposal('910013')
        stig_target = create(:component, :skip_rules, project: project, prefix: 'RSTH-00')
        sign_in author

        post "/requirement_relocations/#{record.id}/accept",
             params: { target_component_id: stig_target.id }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/SRG component/)
        expect(record.reload.executed_at).to be_nil
      end

      it 'returns 422 in SRG wording when the target does not declare the source SRG' do
        other_core = create(:security_requirements_guide, :core, :skip_rules,
                            srg_id: 'SRG-CORE-RELOCAPI-APP', version: 'V1R1')
        uncovered_target = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                           based_on: other_core, prefix: 'RUNC-00')
        catalog_row = create(:srg_rule, security_requirements_guide: core_srg, version: 'SRG-OS-000901')
        source = create(:srg_rule, :authored, component: srg_component, rule_id: '910023',
                                              derived_from_srg_rule_id: catalog_row.id)
        record = RequirementRelocation.create!(source_rule: source, target_technology_token: 'RUNC')
        sign_in author

        post "/requirement_relocations/#{record.id}/accept",
             params: { target_component_id: uncovered_target.id }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join)
          .to match(/does not declare SRG-CORE-RELOCAPI as a source SRG/)
        expect(record.reload.executed_at).to be_nil
      end

      it 'forbids acceptance without author on the target component — source rights do not grant it' do
        other_project = create(:project, visibility: 'discoverable')
        foreign_target = create(:component, :skip_rules, project: other_project,
                                                         document_type: 'srg', based_on: core_srg,
                                                         prefix: 'RFOR-00')
        record = open_proposal('910014')
        sign_in author

        post "/requirement_relocations/#{record.id}/accept",
             params: { target_component_id: foreign_target.id }, as: :json

        # Discoverable project, non-member: an honest 403 per the
        # disclosure policy — never a 500.
        expect(response).to have_http_status(:forbidden)
        expect(record.reload.executed_at).to be_nil
      end

      it 'answers 404 for an executed record' do
        source = authored_row('910015')
        source.update!(deleted_at: Time.current)
        executed = RequirementRelocation.create!(source_rule: source, target_technology_token: 'RTGT',
                                                 executed_at: 1.day.ago)
        sign_in author

        post "/requirement_relocations/#{executed.id}/accept",
             params: { target_component_id: target_component.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'POST /requirement_relocations/:id/decline' do
      it 'declines with a required rationale, retaining the record' do
        record = open_proposal('910016', token: 'RRCV')
        sign_in receiver

        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: receiving_component.id,
                       requirement_relocation: { adjudication_rationale: 'Covered by RRCV-00-000001 already.' } }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig('toast', 'title')).to eq('Non-concurred.')
        record.reload
        expect(record.declined_at).to be_present
        expect(record.declined_by_id).to eq(receiver.id)
        expect(record.adjudication_rationale).to eq('Covered by RRCV-00-000001 already.')
        expect(record.executed_at).to be_nil
      end

      it 'rejects a decline without a rationale' do
        record = open_proposal('910017', token: 'RRCV')
        sign_in receiver

        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: receiving_component.id,
                       requirement_relocation: { adjudication_rationale: '' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/rationale/i)
        expect(record.reload.declined_at).to be_nil
      end

      it 'answers not-found when an accept lands between the decline load and its write' do
        # The lost half of a terminating race, interposed deterministically:
        # the acceptance commits while the decline request holds a stale
        # proposed record (real cross-connection serialization is proven by
        # the executor's threaded spec; this pins the controller guard).
        record = open_proposal('910050', token: 'RRCV')
        interposed = false
        allow_any_instance_of(RelocationExecutor).to receive(:validation_errors)
          .and_wrap_original do |original|
            result = original.call
            unless interposed
              interposed = true
              RelocationExecutor.new(RequirementRelocation.find(record.id),
                                     target_component: receiving_component,
                                     accepted_by: receiver).execute!
            end
            result
          end
        sign_in receiver

        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: receiving_component.id,
                       requirement_relocation: { adjudication_rationale: 'Raced.' } }

        expect(response).to have_http_status(:not_found)
        record.reload
        expect(record.executed_at).to be_present
        expect(record.declined_at).to be_nil
      end

      it 'forbids a viewer from declining' do
        record = open_proposal('910018')
        sign_in viewer

        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: target_component.id,
                       requirement_relocation: { adjudication_rationale: 'No.' } }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(record.reload.declined_at).to be_nil
      end

      it 'rejects a decline anchored to an ineligible component — adjudication binds to an eligible receiver' do
        record = open_proposal('910023')
        stig_component = create(:component, :skip_rules, project: project, prefix: 'RSTD-00')
        sign_in author

        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: stig_component.id,
                       requirement_relocation: { adjudication_rationale: 'Not ours.' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/SRG component/)
        expect(record.reload.declined_at).to be_nil
      end

      it 'rejects a decline anchored to a released component at both layers' do
        record = open_proposal('910026')
        released = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                   based_on: core_srg, prefix: 'RREL-00')
        released.update_column(:released, true)

        # Layer 1 — authz: released components are read-only, so the
        # author role itself is denied there.
        sign_in author
        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: released.id,
                       requirement_relocation: { adjudication_rationale: 'From a released doc.' } },
             as: :json
        expect(response).to have_http_status(:forbidden)

        # Layer 2 — the eligibility oracle catches role-bypassing admins.
        sign_in admin
        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: released.id,
                       requirement_relocation: { adjudication_rationale: 'From a released doc.' } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/released/)

        expect(record.reload.declined_at).to be_nil
      end

      it 'rejects a decline anchored to the source component itself' do
        record = open_proposal('910024')
        sign_in author

        post "/requirement_relocations/#{record.id}/decline",
             params: { target_component_id: srg_component.id,
                       requirement_relocation: { adjudication_rationale: 'Self-decline attempt.' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig('toast', 'message').join).to match(/source component/)
        expect(record.reload.declined_at).to be_nil
      end

      it 'answers 404 when declining an already-declined proposal — directly' do
        source = authored_row('910025')
        declined = RequirementRelocation.create!(source_rule: source, target_technology_token: 'RTGT',
                                                 declined_at: 1.day.ago, declined_by: receiver,
                                                 adjudication_rationale: 'Once is enough.')
        sign_in author

        post "/requirement_relocations/#{declined.id}/decline",
             params: { target_component_id: target_component.id,
                       requirement_relocation: { adjudication_rationale: 'Again.' } }

        expect(response).to have_http_status(:not_found)
        expect(declined.reload.adjudication_rationale).to eq('Once is enough.')
      end

      it 'answers 404 for an already-declined proposal — adjudication is terminal' do
        source = authored_row('910019')
        declined = RequirementRelocation.create!(source_rule: source, target_technology_token: 'RTGT',
                                                 declined_at: 1.day.ago, declined_by: receiver,
                                                 adjudication_rationale: 'Out of scope.')
        sign_in author

        post "/requirement_relocations/#{declined.id}/accept",
             params: { target_component_id: target_component.id }

        expect(response).to have_http_status(:not_found)
        expect(declined.reload.executed_at).to be_nil
      end
    end

    describe 'declined visibility (source side)' do
      it 'serves declined rows in the backlog with the rationale, still excluding executed history' do
        declined_source = authored_row('910020')
        RequirementRelocation.create!(source_rule: declined_source, target_technology_token: 'RVIS',
                                      declined_at: 1.day.ago, declined_by: receiver,
                                      adjudication_rationale: 'Wrong SRG for this control.')
        open_source = authored_row('910021')
        RequirementRelocation.create!(source_rule: open_source, target_technology_token: 'RVIS')
        sign_in author

        get '/requirement_relocations', params: { target_technology_token: 'RVIS' }

        expect(response).to have_http_status(:ok)
        rows = response.parsed_body
        expect(rows.size).to eq(2)
        declined_row = rows.find { |r| r['declined_at'].present? }
        expect(declined_row['adjudication_rationale']).to eq('Wrong SRG for this control.')
        expect(declined_row['declined_by_name']).to eq(receiver.name)
      end

      it 'permits a fresh proposal for the same source after a decline' do
        source = authored_row('910022')
        RequirementRelocation.create!(source_rule: source, target_technology_token: 'CTR',
                                      declined_at: 1.day.ago, declined_by: receiver,
                                      adjudication_rationale: 'Declined once.')
        sign_in author

        post "/rules/#{source.id}/relocations",
             params: { requirement_relocation: { target_technology_token: 'GPOS' } }

        expect(response).to have_http_status(:ok)
        expect(RequirementRelocation.proposed.where(source_rule_id: source.id).count).to eq(1)
      end
    end
  end
end
