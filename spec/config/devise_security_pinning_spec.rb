# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Gemfile devise-security pinning' do
  # devise-security pinned to a branch is non-reproducible.
  # Must pin to a specific git SHA for deterministic builds.

  let(:gemfile) { Rails.root.join('Gemfile').read }

  it 'pins devise-security to a git ref, not a branch' do
    devise_security_line = gemfile.lines.find { |l| l.include?('devise-security') }
    expect(devise_security_line).not_to be_nil, 'devise-security gem not found in Gemfile'
    expect(devise_security_line).not_to match(/branch:/),
                                        'devise-security must not use branch: (non-reproducible)'
    expect(devise_security_line).to match(/ref:/),
                                    'devise-security must use ref: for reproducible builds'
  end
end
