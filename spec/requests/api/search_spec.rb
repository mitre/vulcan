# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Search' do
  # Requirements:
  # - GET /api/search/global returns JSON search results
  # - Requires authentication (returns 401 if not logged in)
  # - Searches projects, components, rules, SRGs, and STIGs
  # - Only returns results user has access to (via membership) for projects/components/rules
  # - SRGs and STIGs are public - any authenticated user can search them
  # - Respects limit parameter (default 5, max 20)
  # - Returns empty for queries < 2 chars

  before do # rubocop:disable RSpec/ScatteredSetup
    Rails.application.reload_routes!
  end

  # Create admin_user FIRST to prevent first-user-admin promotion
  let!(:admin_user) { create(:user, admin: true) }
  let(:user) { create(:user) }

  # Create test data
  # Note: Set visibility to 'hidden' for project2 so it only appears via membership
  # (default visibility is 'discoverable' which would show in search)
  let!(:project1) { create(:project, name: 'Security Baseline Project') }
  let!(:project2) { create(:project, name: 'Another Secret Project', visibility: :hidden) }

  # Components automatically get rules from the SRG via based_on
  let!(:srg) { create(:security_requirements_guide) }
  let!(:component1) { create(:component, project: project1, name: 'Web Server Component', prefix: 'WEBS-01', based_on: srg) }
  let!(:component2) { create(:component, project: project2, name: 'Database Component', prefix: 'DBAS-01', based_on: srg) }

  # Give user access to project1 only (not project2)
  before do # rubocop:disable RSpec/ScatteredSetup
    Membership.create!(membership: project1, user: user, role: 'viewer')
  end

  describe 'GET /api/search/global' do
    context 'when not authenticated' do
      it 'returns 401 Unauthorized' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      before { sign_in user }

      it 'returns empty results for short queries' do
        get '/api/search/global', params: { q: 'a' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects']).to eq([])
        expect(json['components']).to eq([])
        expect(json['rules']).to eq([])
        expect(json['srgs']).to eq([])
        expect(json['stigs']).to eq([])
        expect(json['stig_rules']).to eq([])
        expect(json['srg_rules']).to eq([])
      end

      it 'searches projects by name' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].length).to eq(1)
        expect(json['projects'][0]['name']).to eq('Security Baseline Project')
      end

      it 'only returns projects user has access to' do
        get '/api/search/global', params: { q: 'Another' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # User doesn't have access to project2 (it's hidden and no membership)
        expect(json['projects']).to eq([])
      end

      it 'searches components by name' do
        get '/api/search/global', params: { q: 'Web Server' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['components'].length).to eq(1)
        expect(json['components'][0]['name']).to eq('Web Server Component')
      end

      it 'searches components by prefix' do
        get '/api/search/global', params: { q: 'WEBS' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['components'].length).to eq(1)
        expect(json['components'][0]['name']).to eq('Web Server Component')
      end

      it 'only returns components from accessible projects' do
        get '/api/search/global', params: { q: 'Database' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # component2 belongs to project2 which user doesn't have access to
        expect(json['components']).to eq([])
      end

      it 'respects limit parameter' do
        # Create more projects for the user
        5.times do |i|
          proj = create(:project, name: "Test Searchable Project #{i}")
          Membership.create!(membership: proj, user: user, role: 'viewer')
        end

        get '/api/search/global', params: { q: 'Test', limit: 3 }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].length).to be <= 3
      end

      it 'returns project metadata' do
        get '/api/search/global', params: { q: 'Security' }

        json = response.parsed_body
        project = json['projects'][0]
        expect(project).to have_key('id')
        expect(project).to have_key('name')
        expect(project).to have_key('description')
        expect(project).to have_key('components_count')
      end

      it 'returns component metadata' do
        get '/api/search/global', params: { q: 'Web' }

        json = response.parsed_body
        component = json['components'][0]
        expect(component).to have_key('id')
        expect(component).to have_key('name')
        expect(component).to have_key('version')
        expect(component).to have_key('release')
        expect(component).to have_key('project_id')
        expect(component).to have_key('project_name')
      end
    end

    context 'rules search' do
      before { sign_in user }

      let!(:rule1) do
        rule = component1.rules.first
        rule.update!(
          title: 'Xylophone Configuration Requirements',
          fixtext: 'Configure xylophone to enforce strict policy'
        )
        rule
      end

      it 'searches rules by title' do
        get '/api/search/global', params: { q: 'Xylophone' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['rules'].length).to be >= 1
        expect(json['rules'][0]['title']).to eq('Xylophone Configuration Requirements')
      end

      it 'only returns rules from accessible components' do
        # Update a rule in component2 (which user doesn't have access to)
        rule2 = component2.rules.first
        rule2.update!(title: 'Platypus Secret Configuration')

        get '/api/search/global', params: { q: 'Platypus' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # User doesn't have access to component2's rules
        expect(json['rules']).to eq([])
      end
    end

    context 'SRG search' do
      # Requirements:
      # - SRGs are public resources - any authenticated user can search them
      # - Search by name, title, or srg_id
      # - Return useful metadata: id, name, title, version

      before { sign_in user }

      let!(:srg_rhel) do
        create(:security_requirements_guide,
               srg_id: 'RHEL_9_SRG',
               title: 'Red Hat Enterprise Linux 9 Security Requirements Guide',
               name: 'RHEL 9 SRG - Ver 1, Rel 1',
               version: 'V1R1')
      end

      let!(:srg_windows) do
        create(:security_requirements_guide,
               srg_id: 'WIN_SERVER_2022_SRG',
               title: 'Windows Server 2022 Security Requirements Guide',
               name: 'Windows Server 2022 SRG - Ver 1, Rel 2',
               version: 'V1R2')
      end

      it 'searches SRGs by title' do
        get '/api/search/global', params: { q: 'Red Hat' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['srgs'].length).to eq(1)
        expect(json['srgs'][0]['title']).to include('Red Hat')
      end

      it 'searches SRGs by name' do
        get '/api/search/global', params: { q: 'RHEL' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['srgs'].length).to eq(1)
        expect(json['srgs'][0]['name']).to include('RHEL')
      end

      it 'searches SRGs by srg_id' do
        get '/api/search/global', params: { q: 'WIN_SERVER' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['srgs'].length).to eq(1)
        expect(json['srgs'][0]['srg_id']).to eq('WIN_SERVER_2022_SRG')
      end

      it 'returns SRG metadata' do
        get '/api/search/global', params: { q: 'RHEL' }

        json = response.parsed_body
        srg_result = json['srgs'][0]
        expect(srg_result).to have_key('id')
        expect(srg_result).to have_key('srg_id')
        expect(srg_result).to have_key('name')
        expect(srg_result).to have_key('title')
        expect(srg_result).to have_key('version')
      end

      it 'SRGs are public - available to any authenticated user' do
        # Create a new user with no project memberships
        new_user = create(:user)
        sign_in new_user

        get '/api/search/global', params: { q: 'RHEL' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # User should still find the SRG even though they have no project access
        expect(json['srgs'].length).to eq(1)
      end
    end

    context 'STIG search' do
      # Requirements:
      # - STIGs are public resources - any authenticated user can search them
      # - Search by name, title, stig_id, or description
      # - Return useful metadata: id, name, title, version, description

      before { sign_in user }

      let!(:stig_apache) do
        create(:stig,
               stig_id: 'Apache_Server_2_4_STIG',
               title: 'Apache Server 2.4 Security Technical Implementation Guide',
               name: 'Apache Server 2.4 STIG - Ver 2, Rel 3',
               version: 'V2R3',
               description: 'Security configuration for Apache HTTP Server')
      end

      let!(:stig_nginx) do
        create(:stig,
               stig_id: 'NGINX_Web_Server_STIG',
               title: 'NGINX Web Server Security Technical Implementation Guide',
               name: 'NGINX Web Server STIG - Ver 1, Rel 1',
               version: 'V1R1',
               description: 'Security configuration for NGINX web server')
      end

      it 'searches STIGs by title' do
        get '/api/search/global', params: { q: 'Apache' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stigs'].length).to eq(1)
        expect(json['stigs'][0]['title']).to include('Apache')
      end

      it 'searches STIGs by name' do
        get '/api/search/global', params: { q: 'NGINX' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stigs'].length).to eq(1)
        expect(json['stigs'][0]['name']).to include('NGINX')
      end

      it 'searches STIGs by stig_id' do
        get '/api/search/global', params: { q: 'Apache_Server_2_4' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stigs'].length).to eq(1)
        expect(json['stigs'][0]['stig_id']).to eq('Apache_Server_2_4_STIG')
      end

      it 'searches STIGs by description' do
        get '/api/search/global', params: { q: 'HTTP Server' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stigs'].length).to eq(1)
        expect(json['stigs'][0]['description']).to include('HTTP Server')
      end

      it 'returns STIG metadata' do
        get '/api/search/global', params: { q: 'Apache' }

        json = response.parsed_body
        stig_result = json['stigs'][0]
        expect(stig_result).to have_key('id')
        expect(stig_result).to have_key('stig_id')
        expect(stig_result).to have_key('name')
        expect(stig_result).to have_key('title')
        expect(stig_result).to have_key('version')
        expect(stig_result).to have_key('description')
      end

      it 'STIGs are public - available to any authenticated user' do
        # Create a new user with no project memberships
        new_user = create(:user)
        sign_in new_user

        get '/api/search/global', params: { q: 'Apache' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # User should still find the STIG even though they have no project access
        expect(json['stigs'].length).to eq(1)
      end
    end

    context 'STIG rules search' do
      # Requirements:
      # - STIG rules are public resources - any authenticated user can search them
      # - Search by rule_id, vuln_id, title, fixtext, or check content
      # - Example: searching '/etc/sudoers' should find rules with that in check content
      # - Return useful metadata: id, rule_id, vuln_id, title, stig name

      before { sign_in user }

      # Create a simple STIG without importing rules from XML
      let!(:rhel_stig) do
        # Skip after_create callback to avoid XML import
        Stig.skip_callback(:create, :after, :import_stig_rules)
        stig = Stig.create!(
          stig_id: 'RHEL_9_STIG',
          title: 'Red Hat Enterprise Linux 9 STIG',
          name: 'RHEL 9 STIG - Ver 1, Rel 3',
          version: 'V1R3',
          description: 'RHEL 9 security configuration',
          xml: '<Benchmark/>'
        )
        Stig.set_callback(:create, :after, :import_stig_rules)
        stig
      end

      let!(:sudoers_rule) do
        rule = StigRule.create!(
          stig: rhel_stig,
          rule_id: 'RHEL-09-654215',
          vuln_id: 'V-258217',
          title: 'RHEL 9 must generate audit records for privileged activities',
          status: 'Applicable - Configurable',
          rule_severity: 'medium',
          rule_weight: '10.0',
          version: 'SV-258217r926638_rule',
          fixtext: 'Configure /etc/sudoers to generate audit records.'
        )
        Check.create!(base_rule: rule, content: 'Verify /etc/sudoers file permissions and audit configuration.')
        rule
      end

      let!(:sshd_rule) do
        rule = StigRule.create!(
          stig: rhel_stig,
          rule_id: 'RHEL-09-252010',
          vuln_id: 'V-257843',
          title: 'RHEL 9 must configure sshd to use approved encryption',
          status: 'Applicable - Configurable',
          rule_severity: 'high',
          rule_weight: '10.0',
          version: 'SV-257843r925885_rule',
          fixtext: 'Configure sshd_config with approved ciphers.',
          ident: 'CCI-000018, CCI-000130, CCI-000135'
        )
        Check.create!(base_rule: rule, content: 'Verify /etc/ssh/sshd_config contains approved cipher settings.')
        rule
      end

      it 'searches STIG rules by check content' do
        get '/api/search/global', params: { q: '/etc/sudoers' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stig_rules'].length).to eq(1)
        expect(json['stig_rules'][0]['rule_id']).to eq('RHEL-09-654215')
      end

      it 'searches STIG rules by rule_id' do
        get '/api/search/global', params: { q: 'RHEL-09-252010' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stig_rules'].length).to eq(1)
        expect(json['stig_rules'][0]['rule_id']).to eq('RHEL-09-252010')
      end

      it 'searches STIG rules by vuln_id' do
        get '/api/search/global', params: { q: 'V-258217' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stig_rules'].length).to eq(1)
        expect(json['stig_rules'][0]['vuln_id']).to eq('V-258217')
      end

      it 'searches STIG rules by title' do
        # Title: "RHEL 9 must configure sshd to use approved encryption"
        get '/api/search/global', params: { q: 'configure sshd' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stig_rules'].length).to eq(1)
        expect(json['stig_rules'][0]['title']).to include('sshd')
      end

      it 'searches STIG rules by fixtext' do
        # Fixtext: "Configure sshd_config with approved ciphers."
        get '/api/search/global', params: { q: 'sshd_config' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stig_rules'].length).to eq(1)
        expect(json['stig_rules'][0]['fixtext']).to include('sshd_config')
      end

      it 'returns STIG rule metadata' do
        get '/api/search/global', params: { q: '/etc/sudoers' }

        json = response.parsed_body
        stig_rule = json['stig_rules'][0]
        expect(stig_rule).to have_key('id')
        expect(stig_rule).to have_key('rule_id')
        expect(stig_rule).to have_key('vuln_id')
        expect(stig_rule).to have_key('title')
        expect(stig_rule).to have_key('stig_id')
        expect(stig_rule).to have_key('stig_name')
      end

      it 'searches STIG rules by CCI identifier' do
        get '/api/search/global', params: { q: 'CCI-000130' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stig_rules'].length).to eq(1)
        expect(json['stig_rules'][0]['ident']).to include('CCI-000130')
      end

      it 'STIG rules are public - available to any authenticated user' do
        new_user = create(:user)
        sign_in new_user

        get '/api/search/global', params: { q: '/etc/sudoers' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['stig_rules'].length).to eq(1)
      end
    end

    context 'SRG rules search' do
      # Requirements:
      # - SRG rules are public resources - any authenticated user can search them
      # - Search by rule_id, title, fixtext, ident (CCIs), check content
      # - Return useful metadata: id, rule_id, title, srg name

      before { sign_in user }

      # Use an existing SRG from the test setup (created for component factory)
      # Note: The SRG created by the component factory already has srg_rules

      let!(:custom_srg) do
        # Skip after_create callback to avoid XML import
        SecurityRequirementsGuide.skip_callback(:create, :after, :import_srg_rules)
        srg = SecurityRequirementsGuide.create!(
          srg_id: 'Custom_Test_SRG',
          title: 'Custom Test Security Requirements Guide',
          name: 'Custom Test SRG - Ver 1, Rel 1',
          version: 'V1R1',
          xml: '<Benchmark/>'
        )
        SecurityRequirementsGuide.set_callback(:create, :after, :import_srg_rules)
        srg
      end

      let!(:firewall_srg_rule) do
        SrgRule.create!(
          security_requirements_guide: custom_srg,
          rule_id: 'SRG-OS-000480-GPOS-00232',
          title: 'The operating system must configure firewall rules',
          status: 'Applicable - Configurable',
          rule_severity: 'medium',
          rule_weight: '10.0',
          version: 'RHEL-09-OS-00232',
          fixtext: 'Configure firewalld with appropriate zone settings.',
          ident: 'CCI-000366, CCI-002385'
        )
      end

      it 'searches SRG rules by rule_id' do
        get '/api/search/global', params: { q: 'SRG-OS-000480' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['srg_rules'].length).to eq(1)
        expect(json['srg_rules'][0]['rule_id']).to include('SRG-OS-000480')
      end

      it 'searches SRG rules by title' do
        get '/api/search/global', params: { q: 'firewall rules' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['srg_rules'].length).to eq(1)
        expect(json['srg_rules'][0]['title']).to include('firewall')
      end

      it 'searches SRG rules by CCI identifier' do
        # Use full CCI to be more specific and avoid matches from factory-created SRG rules
        get '/api/search/global', params: { q: 'CCI-002385' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # Find our specific rule in results
        matching_rules = json['srg_rules'].select { |r| r['ident']&.include?('CCI-002385') }
        expect(matching_rules.length).to be >= 1
        expect(matching_rules.first['ident']).to include('CCI-002385')
      end

      it 'returns SRG rule metadata' do
        get '/api/search/global', params: { q: 'firewall rules' }

        json = response.parsed_body
        srg_rule = json['srg_rules'][0]
        expect(srg_rule).to have_key('id')
        expect(srg_rule).to have_key('rule_id')
        expect(srg_rule).to have_key('title')
        expect(srg_rule).to have_key('srg_id')
        expect(srg_rule).to have_key('srg_name')
      end

      it 'SRG rules are public - available to any authenticated user' do
        new_user = create(:user)
        sign_in new_user

        get '/api/search/global', params: { q: 'firewall rules' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['srg_rules'].length).to eq(1)
      end
    end
  end
end
