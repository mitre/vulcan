# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'admin per-request query limits' do
  # REQUIREMENT: Queries that run on every admin page load must have a limit
  # to prevent unbounded result sets from degrading performance.

  include ConfigFileHelpers

  let(:controller) { Rails.root.join('app/controllers/application_controller.rb').read }

  it 'locked_users query has a result limit' do
    method_body = extract_method(controller, 'check_locked_user_notifications')
    expect(method_body).to match(/\.limit\(\d+\)/),
                           'locked_users query must have a limit to prevent unbounded results on every page load'
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
