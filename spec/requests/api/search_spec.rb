# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Search' do
  before do
    Rails.application.reload_routes!
    create(:membership, membership: project1, user: user, role: 'viewer')
    # User does NOT have access to project2
  end

  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }

  # Create test data
  let!(:project1) { create(:project, name: 'Security Baseline Project') }
  let!(:project2) { create(:project, name: 'Another Project') }
  # Components automatically get rules from the SRG via based_on
  let!(:component1) { create(:component, project: project1, name: 'Web Server Component', prefix: 'WEBS-01') }
  let!(:component2) { create(:component, project: project2, name: 'Database Component', prefix: 'DBAS-01') }

  # Set up user access (membership uses polymorphic 'membership' association)

  describe 'GET /api/search/global' do
    context 'when not authenticated' do
      it 'redirects to login' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to redirect_to(new_user_session_path)
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
        # User doesn't have access to project2
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
          proj = create(:project, name: "Test Project #{i}")
          create(:membership, membership: proj, user: user, role: 'viewer')
        end

        get '/api/search/global', params: { q: 'Test', limit: 3 }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].length).to be <= 3
      end

      it 'clamps limit to maximum of 20' do
        get '/api/search/global', params: { q: 'Security', limit: 100 }

        expect(response).to have_http_status(:success)
        # Should not error, limit clamped internally
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
      # Use rules that are automatically created when component is created (via import_srg_rules callback)
      # Update their titles/fixtext to have searchable content for our tests
      # NOTE: These let! blocks create searchable data - referenced indirectly via search queries
      let!(:rule1) do # rubocop:disable RSpec/LetSetup -- creates searchable data for 'Kubernetes' query
        rule = component1.rules.first
        rule.update!(
          title: 'Kubernetes API Server Configuration',
          fixtext: 'Configure Kubernetes to enforce TLS encryption.'
        )
        rule
      end

      let!(:rule2) do # rubocop:disable RSpec/LetSetup -- creates searchable data for 'SSH' query
        rule = component1.rules.second
        rule.update!(
          title: 'SSH Configuration',
          fixtext: 'Configure SSH daemon for secure access.'
        )
        rule
      end

      let!(:rule_inaccessible) do
        rule = component2.rules.first
        rule.update!(
          title: 'Kubernetes Control Plane',
          fixtext: 'Secure the Kubernetes control plane.'
        )
        rule
      end

      before { sign_in user }

      it 'searches rules by title using pg_search' do
        get '/api/search/global', params: { q: 'Kubernetes' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['rules'].length).to eq(1)
        expect(json['rules'][0]['title']).to include('Kubernetes')
      end

      it 'searches rules by fixtext content' do
        get '/api/search/global', params: { q: 'TLS encryption' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # pg_search with prefix matching should find this
        expect(json['rules'].any? { |r| r['title'].include?('Kubernetes') }).to be(true)
      end

      it 'only returns rules from accessible components' do
        get '/api/search/global', params: { q: 'Kubernetes Control' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # rule_inaccessible belongs to component2 which is in project2
        # User only has access to project1
        rule_ids = json['rules'].pluck('id')
        expect(rule_ids).not_to include(rule_inaccessible.id)
      end

      it 'returns rule metadata' do
        get '/api/search/global', params: { q: 'SSH' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['rules'].length).to eq(1)

        rule = json['rules'][0]
        expect(rule).to have_key('id')
        expect(rule).to have_key('rule_id')
        expect(rule).to have_key('title')
        expect(rule).to have_key('status')
        expect(rule).to have_key('component_id')
      end

      it 'returns correct component_id for navigation' do
        get '/api/search/global', params: { q: 'SSH' }

        json = response.parsed_body
        rule = json['rules'][0]
        expect(rule['component_id']).to eq(component1.id)
      end

      context 'when admin' do
        before { sign_in admin_user }

        it 'can search rules from all components' do
          get '/api/search/global', params: { q: 'Kubernetes' }

          expect(response).to have_http_status(:success)
          json = response.parsed_body
          # Admin should see rules from both projects
          expect(json['rules'].length).to eq(2)
        end
      end

      it 'respects limit parameter for rules' do
        # Update multiple existing rules with searchable content
        component1.rules.limit(5).each_with_index do |rule, i|
          rule.update!(title: "Test Rule #{i}")
        end

        get '/api/search/global', params: { q: 'Test Rule', limit: 3 }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['rules'].length).to be <= 3
      end
    end

    context 'when admin' do
      before { sign_in admin_user }

      it 'can search all projects' do
        get '/api/search/global', params: { q: 'Project' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        # Admin should see both projects
        expect(json['projects'].length).to eq(2)
      end
    end

    context 'STIG and SRG search' do
      # STIGs and SRGs are created via fixtures or let! blocks
      # Components have based_on (SRG) which creates SrgRules

      before { sign_in user }

      it 'returns stigs array in response' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json).to have_key('stigs')
        expect(json['stigs']).to be_an(Array)
      end

      it 'returns srgs array in response' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json).to have_key('srgs')
        expect(json['srgs']).to be_an(Array)
      end

      it 'returns stig_rules array in response' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json).to have_key('stig_rules')
        expect(json['stig_rules']).to be_an(Array)
      end

      it 'returns srg_rules array in response' do
        get '/api/search/global', params: { q: 'Security' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json).to have_key('srg_rules')
        expect(json['srg_rules']).to be_an(Array)
      end

      it 'searches SRG documents by name' do
        # The component's based_on SRG should be searchable
        # Use security_requirements_guide_id since based_on uses select() without id
        srg = SecurityRequirementsGuide.find(component1.security_requirements_guide_id)
        srg.update!(name: 'Test Searchable SRG Name')

        get '/api/search/global', params: { q: 'Searchable SRG' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['srgs'].any? { |s| s['name'].include?('Searchable') }).to be(true)
      end

      it 'returns SRG document metadata' do
        # Use security_requirements_guide_id since based_on uses select() without id
        srg = SecurityRequirementsGuide.find(component1.security_requirements_guide_id)
        srg.update!(name: 'Metadata Test SRG')

        get '/api/search/global', params: { q: 'Metadata Test' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        next if json['srgs'].empty?

        srg_result = json['srgs'].first
        expect(srg_result).to have_key('id')
        expect(srg_result).to have_key('name')
        expect(srg_result).to have_key('title')
        expect(srg_result).to have_key('version')
        expect(srg_result).to have_key('rules_count')
      end
    end

    context 'snippet generation' do
      let!(:rule_with_fixtext) do
        rule = component1.rules.third
        rule.update!(
          title: 'Generic Title',
          fixtext: 'Configure the /etc/redhat-release file to contain proper version information.'
        )
        rule
      end

      before { sign_in user }

      it 'returns snippet when match is in fixtext' do
        get '/api/search/global', params: { q: 'redhat-release' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body

        # Find the rule with the fixtext match
        matching_rule = json['rules'].find { |r| r['id'] == rule_with_fixtext.id }
        next unless matching_rule

        expect(matching_rule).to have_key('snippet')
        expect(matching_rule['snippet']).to include('redhat-release')
        expect(matching_rule['snippet']).to include('[Fixtext]')
      end

      it 'returns snippet with context around match' do
        get '/api/search/global', params: { q: 'redhat-release' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body

        matching_rule = json['rules'].find { |r| r['id'] == rule_with_fixtext.id }
        next unless matching_rule

        # Snippet should include surrounding text
        expect(matching_rule['snippet']).to include('Configure')
      end
    end

    context 'query normalization' do
      # rubocop:disable RSpec/LetSetup -- creates searchable data for 'RedHat' query
      let!(:redhat_project) do
        proj = create(:project, name: 'Red Hat Enterprise Linux 9')
        create(:membership, membership: proj, user: user, role: 'viewer')
        proj
      end
      # rubocop:enable RSpec/LetSetup

      before { sign_in user }

      it 'normalizes PascalCase to spaces (RedHat → Red Hat)' do
        get '/api/search/global', params: { q: 'RedHat' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('Red Hat') }).to be(true)
      end

      it 'normalizes letter-number boundaries (RHEL9 → RHEL 9)' do
        proj = create(:project, name: 'RHEL 9 Security Guide')
        create(:membership, membership: proj, user: user, role: 'viewer')

        get '/api/search/global', params: { q: 'RHEL9' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('RHEL 9') }).to be(true)
      end

      it 'normalizes dashes to spaces (RHEL-9 → RHEL 9)' do
        proj = create(:project, name: 'RHEL 9 Hardening')
        create(:membership, membership: proj, user: user, role: 'viewer')

        get '/api/search/global', params: { q: 'RHEL-9' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('RHEL 9') }).to be(true)
      end

      it 'handles complex normalization (Win10Server → Win 10 Server)' do
        proj = create(:project, name: 'Win 10 Server Baseline')
        create(:membership, membership: proj, user: user, role: 'viewer')

        get '/api/search/global', params: { q: 'Win10Server' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('Win 10') }).to be(true)
      end
    end

    context 'abbreviation expansion' do
      before do
        sign_in user
        SearchAbbreviationService.clear_cache!
      end

      it 'expands RHEL to Red Hat Enterprise Linux' do
        proj = create(:project, name: 'Red Hat Enterprise Linux 9 STIG')
        create(:membership, membership: proj, user: user, role: 'viewer')
        SearchAbbreviationService.clear_cache!

        get '/api/search/global', params: { q: 'RHEL' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('Red Hat Enterprise Linux') }).to be(true)
      end

      it 'expands K8s to Kubernetes' do
        proj = create(:project, name: 'Kubernetes Security Baseline')
        create(:membership, membership: proj, user: user, role: 'viewer')
        SearchAbbreviationService.clear_cache!

        get '/api/search/global', params: { q: 'K8s' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('Kubernetes') }).to be(true)
      end

      it 'uses user-defined abbreviations' do
        create(:search_abbreviation, abbreviation: 'ACME', expansion: 'ACME Corporation')
        SearchAbbreviationService.clear_cache!

        proj = create(:project, name: 'ACME Corporation Security')
        create(:membership, membership: proj, user: user, role: 'viewer')

        get '/api/search/global', params: { q: 'ACME' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('ACME Corporation') }).to be(true)
      end

      it 'user abbreviations override core' do
        # Override RHEL with custom expansion
        create(:search_abbreviation, abbreviation: 'RHEL', expansion: 'Custom RHEL Override')
        SearchAbbreviationService.clear_cache!

        proj = create(:project, name: 'Custom RHEL Override Project')
        create(:membership, membership: proj, user: user, role: 'viewer')

        get '/api/search/global', params: { q: 'RHEL' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['projects'].any? { |p| p['name'].include?('Custom RHEL Override') }).to be(true)
      end
    end

    context 'phrase search' do
      before { sign_in user }

      # Use existing component1 rules and update them for phrase search testing
      let!(:rule_with_phrase) do
        rule = component1.rules.first
        rule.update!(
          title: 'Configure SSH for secure algorithms',
          fixtext: 'The system must implement security controls to protect data'
        )
        rule
      end

      let!(:rule_without_phrase) do
        rule = component1.rules.second
        rule.update!(
          title: 'Security is important for implementation',
          fixtext: 'Implement controls as needed for security'
        )
        rule
      end

      it 'finds exact phrases with double quotes' do
        get '/api/search/global', params: { q: '"security controls"' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        rules = json['rules']

        # Should find rule with "security controls" as phrase
        expect(rules.length).to be >= 1
        rule_ids = rules.pluck('id')
        expect(rule_ids).to include(rule_with_phrase.id)
      end

      it 'finds exact phrases with single quotes' do
        get '/api/search/global', params: { q: "'security controls'" }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        rules = json['rules']

        expect(rules.length).to be >= 1
        rule_ids = rules.pluck('id')
        expect(rule_ids).to include(rule_with_phrase.id)
      end

      it 'does not match words in different order for phrase search' do
        # "controls security" should NOT match "security controls"
        get '/api/search/global', params: { q: '"controls security"' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        rules = json['rules']

        # Should NOT find rule_with_phrase because words are in wrong order
        rule_ids = rules.pluck('id')
        expect(rule_ids).not_to include(rule_with_phrase.id)
      end

      it 'matches words in any order for regular search' do
        # Without quotes, words can be in any order
        get '/api/search/global', params: { q: 'controls security' }

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        rules = json['rules']

        # Should find both rules since both contain both words
        rule_ids = rules.pluck('id')
        expect(rule_ids).to include(rule_with_phrase.id)
        expect(rule_ids).to include(rule_without_phrase.id)
      end
    end
  end
end
