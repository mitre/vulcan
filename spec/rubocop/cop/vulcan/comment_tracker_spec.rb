# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/rubocop/cop/vulcan/comment_tracker'

RSpec.describe RuboCop::Cop::Vulcan::CommentTracker, :config do
  let(:msg) { 'Do not reference tracker IDs in source comments.' }

  it 'registers offense for vulcan-clean- reference and strips it' do
    expect_offense(<<~RUBY)
      # vulcan-clean-abc123: fix later
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY

    expect_correction(<<~RUBY)
      # fix later
    RUBY
  end

  it 'registers offense for vulcan-v3.x- inline reference and removes comment' do
    expect_offense(<<~RUBY)
      x = 1 # vulcan-v3.x-def456
            ^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY

    expect_correction(<<~RUBY)
      x = 1
    RUBY
  end

  it 'registers offense for vulcan-v2.x- standalone reference and removes line' do
    expect_offense(<<~RUBY)
      # vulcan-v2.x-ghi789
      ^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY

    expect_correction('')
  end

  it 'strips parenthesized reference, preserves surrounding text' do
    expect_offense(<<~RUBY)
      # Batch per-project counts via GROUP BY (vulcan-v3.x-73z.9).
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY

    expect_correction(<<~RUBY)
      # Batch per-project counts via GROUP BY.
    RUBY
  end

  it 'strips reference with section number' do
    expect_offense(<<~RUBY)
      # Single CASE UPDATE per column (vulcan-v3.x-480.6 §18.4).
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY

    expect_correction(<<~RUBY)
      # Single CASE UPDATE per column.
    RUBY
  end

  it 'strips trailing reference after period' do
    expect_offense(<<~RUBY)
      # DB ids changed between merges. vulcan-v3.x-480.7.
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY

    expect_correction(<<~RUBY)
      # DB ids changed between merges.
    RUBY
  end

  it 'strips leading reference with colon' do
    expect_offense(<<~RUBY)
      # vulcan-v3.x-aik: keep named routes ABOVE the catch-all
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY

    expect_correction(<<~RUBY)
      # keep named routes ABOVE the catch-all
    RUBY
  end

  it 'does not flag normal comments' do
    expect_no_offenses(<<~RUBY)
      # This is a normal comment
      x = 1 # another normal comment
    RUBY
  end

  it 'does not flag vulcan_ without dash-prefix pattern' do
    expect_no_offenses(<<~RUBY)
      # vulcan_audited tracks changes
      # See vulcan.default.yml for settings
    RUBY
  end
end
