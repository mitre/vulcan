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
RSpec.describe User, type: :model do
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
end
