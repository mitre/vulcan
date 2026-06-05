# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/rubocop/cop/vulcan/let_it_be_refind'

RSpec.describe RuboCop::Cop::Vulcan::LetItBeRefind, :config do
  let(:msg) { described_class::MSG }

  it 'registers an offense for let_it_be with refind: false' do
    expect_offense(<<~RUBY)
      let_it_be(:user, refind: false) { create(:user) }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'does not register an offense for plain let_it_be (uses global default)' do
    expect_no_offenses(<<~RUBY)
      let_it_be(:user) { create(:user) }
    RUBY
  end

  it 'does not register an offense for let_it_be with refind: true' do
    expect_no_offenses(<<~RUBY)
      let_it_be(:user, refind: true) { create(:user) }
    RUBY
  end

  it 'does not register an offense for let_it_be with reload: true' do
    expect_no_offenses(<<~RUBY)
      let_it_be(:user, reload: true) { create(:user) }
    RUBY
  end

  it 'does not register an offense for let_it_be with freeze: true' do
    expect_no_offenses(<<~RUBY)
      let_it_be(:user, freeze: true) { create(:user) }
    RUBY
  end
end
