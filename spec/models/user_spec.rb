# frozen_string_literal: true

require 'rails_helper'

# Requirements:
# 1. User sessions must timeout after the configured period (default: 60 minutes)
# 2. Remember-me tokens must extend sessions beyond timeout when enabled
# 3. Devise's timeoutable and rememberable modules must be properly coordinated
# 4. All devise modules must be loaded in a single call (except omniauthable)
#    so Devise can properly manage module interactions
#
# Bug: Prior to this fix, :timeoutable was in a separate devise call (line 6)
# from :rememberable (line 12), which broke Devise's ability to check
# remember-me tokens before timing out a session.
RSpec.describe User do
  describe 'devise module configuration' do
    it 'includes the timeoutable module' do
      expect(User.devise_modules).to include(:timeoutable)
    end

    it 'includes the rememberable module' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes all expected authentication modules' do
      expected_modules = %i[
        database_authenticatable registerable rememberable
        recoverable confirmable trackable validatable
        timeoutable omniauthable
      ]

      expected_modules.each do |mod|
        expect(User.devise_modules).to include(mod),
                                       "Expected User.devise_modules to include :#{mod}"
      end
    end

    it 'has timeout_in configured via TimeoutParser' do
      expected = TimeoutParser.parse(Settings.local_login.session_timeout).seconds
      expect(User.timeout_in).to be_present
      expect(User.timeout_in).to eq(expected)
    end

    # This is the key test: timeoutable and rememberable must be in the same
    # devise call so Devise properly sets up the module interaction.
    # When they are in separate calls, Devise may not check remember-me
    # tokens before timing out a session.
    it 'declares timeoutable and rememberable in the same devise call' do
      # Read the actual source file and verify the devise declarations
      source = Rails.root.join('app/models/user.rb').read

      # Split source into logical devise statements by finding lines that
      # start with 'devise' and collecting continuation lines (those starting
      # with whitespace followed by a colon, indicating symbol args)
      lines = source.lines
      devise_statements = []
      current_statement = nil

      lines.each do |line|
        if /^\s*devise\s+/.match?(line)
          # Start of a new devise call
          devise_statements << current_statement if current_statement
          current_statement = line.strip
        elsif current_statement && line =~ /^\s+:/ # Continuation line with symbols
          current_statement += " #{line.strip}"
        else
          # End of current devise call (if any)
          devise_statements << current_statement if current_statement
          current_statement = nil
        end
      end
      devise_statements << current_statement if current_statement

      # There should be exactly 2 devise calls:
      # 1. Main call with all modules including timeoutable and rememberable
      # 2. omniauthable (needs separate call for provider config)
      expect(devise_statements.length).to eq(2),
                                          'Expected exactly 2 devise calls (main + omniauthable), ' \
                                          "found #{devise_statements.length}: #{devise_statements.inspect}. " \
                                          'All non-omniauthable modules must be in a single devise call.'

      # Find which call contains timeoutable and which contains rememberable
      main_call = devise_statements.find { |s| s.include?(':timeoutable') }
      rememberable_call = devise_statements.find { |s| s.include?(':rememberable') }

      expect(main_call).not_to be_nil, 'No devise call contains :timeoutable'
      expect(rememberable_call).not_to be_nil, 'No devise call contains :rememberable'

      # They MUST be in the same call
      expect(main_call).to eq(rememberable_call),
                           ':timeoutable and :rememberable must be in the same devise call ' \
                           'so Devise can coordinate timeout checking with remember-me tokens'
    end
  end

  describe 'timeoutable behavior' do
    let(:user) { create(:user) }

    it 'responds to timedout? method' do
      expect(user).to respond_to(:timedout?)
    end

    it 'responds to timeout_in method' do
      expect(user).to respond_to(:timeout_in)
    end

    it 'times out after the configured period' do
      # Simulate a last request time older than timeout_in
      last_access = (User.timeout_in + 1.minute).ago
      expect(user.timedout?(last_access)).to be true
    end

    it 'does not time out within the configured period' do
      last_access = (User.timeout_in - 1.minute).ago
      expect(user.timedout?(last_access)).to be false
    end
  end

  describe 'rememberable behavior' do
    let(:user) { create(:user) }

    it 'responds to remember_me! method' do
      expect(user).to respond_to(:remember_me!)
    end

    it 'responds to forget_me! method' do
      expect(user).to respond_to(:forget_me!)
    end

    it 'has remember_created_at column' do
      expect(User.column_names).to include('remember_created_at')
    end

    it 'can set and clear remember token' do
      user.remember_me!
      expect(user.remember_created_at).to be_present

      user.forget_me!
      expect(user.reload.remember_created_at).to be_nil
    end
  end

  # PR-717 review remediation .j4a step D1 — User#destroy preserves
  # commenter attribution on the user's reviews. dependent: :nullify
  # already drops the FK, but without copying name + email into
  # commenter_imported_* first, the reviews end up with NO attribution
  # anywhere (commenter_display_name returns nil → display surface shows
  # an em-dash). The before_destroy callback (prepend: true so it runs
  # before the dependent :nullify callback Rails generates) copies
  # user.email + user.name into each review's commenter_imported_*.
  describe '#destroy preserves commenter attribution on reviews' do
    let(:project) { Project.create!(name: 'pr717-j4a-d1') }
    let(:srg_xml) { Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read }
    let(:srg) do
      parsed = Xccdf::Benchmark.parse(srg_xml)
      sr = SecurityRequirementsGuide.from_mapping(parsed)
      sr.xml = srg_xml
      sr.save!
      sr
    end
    let(:component) do
      Component.create!(project: project, name: 'PR717 j4a D1', title: 'PR717 j4a D1',
                        version: 'v1', prefix: 'PRJD-01', based_on: srg)
    end
    let(:rule) { component.rules.first }
    let(:commenter) { create(:user, email: 'commenter-d1@example.com', name: 'Commenter Dee') }

    before do
      Membership.find_or_create_by!(user: commenter, membership: project) { |m| m.role = 'viewer' }
    end

    it 'sets commenter_imported_email + commenter_imported_name on each review' do
      review = Review.create!(action: 'comment', comment: 'a comment', user: commenter,
                              rule: rule, triage_status: 'pending')
      commenter.destroy
      review.reload
      expect(review.user_id).to be_nil
      expect(review.commenter_imported_email).to eq('commenter-d1@example.com')
      expect(review.commenter_imported_name).to eq('Commenter Dee')
    end

    it 'covers every review the user authored (multi-row case)' do
      r1 = Review.create!(action: 'comment', comment: 'one', user: commenter, rule: rule, triage_status: 'pending')
      r2 = Review.create!(action: 'comment', comment: 'two', user: commenter,
                          rule: component.rules.second, triage_status: 'pending')
      commenter.destroy
      [r1, r2].each(&:reload)
      expect([r1.user_id, r2.user_id]).to all(be_nil)
      expect([r1.commenter_imported_email, r2.commenter_imported_email])
        .to all(eq('commenter-d1@example.com'))
    end

    it 'does not touch reviews from other users' do
      other = create(:user, email: 'other-d1@example.com', name: 'Other User')
      Membership.find_or_create_by!(user: other, membership: project) { |m| m.role = 'viewer' }
      mine = Review.create!(action: 'comment', comment: 'mine', user: commenter,
                            rule: rule, triage_status: 'pending')
      theirs = Review.create!(action: 'comment', comment: 'theirs', user: other,
                              rule: rule, triage_status: 'pending')
      commenter.destroy
      mine.reload
      theirs.reload
      expect(mine.user_id).to be_nil
      expect(mine.commenter_imported_email).to eq('commenter-d1@example.com')
      expect(theirs.user_id).to eq(other.id)
      expect(theirs.commenter_imported_email).to be_nil
    end

    it 'commenter_display_name resolves to imported_name post-destroy' do
      review = Review.create!(action: 'comment', comment: 'd', user: commenter,
                              rule: rule, triage_status: 'pending')
      commenter.destroy
      expect(review.reload.commenter_display_name).to eq('Commenter Dee')
      expect(review.commenter_imported?).to be(true)
    end
  end
end
