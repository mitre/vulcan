# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'vulcan:auth:rename_provider' do
  before(:all) do
    Rails.application.load_tasks
  end

  let!(:oidc_user) { create(:user, provider: 'oidc', uid: 'oidc-rename-1') }
  let!(:oidc_identity) { create(:identity, user: oidc_user, provider: 'oidc', uid: 'oidc-rename-1') }
  let!(:ldap_user) { create(:user, provider: 'ldap', uid: 'ldap-1') }
  let!(:ldap_identity) { create(:identity, user: ldap_user, provider: 'ldap', uid: 'ldap-1') }

  after { Rake::Task['vulcan:auth:rename_provider'].reenable }

  it 'renames provider on both identities and users tables' do
    Rake::Task['vulcan:auth:rename_provider'].invoke('oidc', 'okta')

    expect(oidc_identity.reload.provider).to eq('okta')
    expect(oidc_user.reload.provider).to eq('okta')
  end

  it 'leaves other providers untouched' do
    Rake::Task['vulcan:auth:rename_provider'].invoke('oidc', 'okta')

    expect(ldap_identity.reload.provider).to eq('ldap')
    expect(ldap_user.reload.provider).to eq('ldap')
  end

  it 'reports the count of renamed rows' do
    output = capture_stdout { Rake::Task['vulcan:auth:rename_provider'].invoke('oidc', 'okta') }
    expect(output).to include('1 identity').or include('1 user')
  end

  it 'refuses blank arguments' do
    expect { Rake::Task['vulcan:auth:rename_provider'].invoke('', 'okta') }
      .to output(/old.*new.*required/i).to_stdout.or raise_error(ArgumentError)
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
