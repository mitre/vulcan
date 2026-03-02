# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'password generation security' do
  # REQUIREMENT: Admin-generated passwords must not have predictable structure.
  # A fixed pattern like [base][UU][ll][dd][ss] makes the last 8 chars guessable.
  # Characters must be shuffled after assembly.

  include ConfigFileHelpers

  let(:controller) { Rails.root.join('app/controllers/users_controller.rb').read }

  it 'shuffles generated password characters to prevent structural predictability' do
    method_body = extract_method(controller, 'generate_compliant_password')
    expect(method_body).to match(/shuffle/),
                           'Generated password must be shuffled to prevent predictable structure'
  end

  private

  def extract_method(source, method_name)
    in_method = false
    lines = []
    source.each_line do |line|
      if line.match?(/def #{method_name}\b/)
        in_method = true
        next
      end
      next unless in_method
      break if line.match?(/^\s+def\s/)

      lines << line
    end
    lines.join
  end
end
