# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'controller class variable safety' do
  # Class variables (@@var) are shared across ALL threads and requests in
  # multi-threaded servers like Puma. One user's data can clobber another's.
  # Controllers must use session, instance variables, or params instead.

  include ConfigFileHelpers

  it 'projects_controller.rb has no class variables' do
    matches = grep_config('app/controllers/projects_controller.rb', /@@\w+/)
    expect(matches).to be_empty,
                       "Class variables found in projects_controller.rb (thread-unsafe):\n#{matches.join}"
  end

  it 'no controller uses class variables' do
    matches = grep_ruby_dir('app/controllers', /@@\w+/)
    expect(matches).to be_empty,
                       "Class variables found in controllers (thread-unsafe):\n#{matches.join("\n")}"
  end
end
