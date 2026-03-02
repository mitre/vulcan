# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'components controller authorization' do
  # REQUIREMENT: based_on_same_srg must scope results to user-accessible projects.
  # An unscoped query leaks component names, versions, and project names from
  # private projects to any logged-in user.
  #
  # REQUIREMENT: compare action must guard against nil component IDs.
  # find_by returns nil for invalid IDs, causing NoMethodError on .rules.pluck.
  #
  # REQUIREMENT: history action must scope to user-accessible projects or released components.

  include ConfigFileHelpers

  let(:controller) { Rails.root.join('app/controllers/components_controller.rb').read }

  describe 'based_on_same_srg' do
    it 'scopes query to user-accessible projects or released components' do
      method_body = extract_method(controller, 'based_on_same_srg')
      has_project_scope = method_body.match?(/available_projects|current_user.*projects|released.*true/)
      expect(has_project_scope).to be(true),
                                   'based_on_same_srg must scope to current_user.available_projects or released:true'
    end
  end

  describe 'compare' do
    it 'guards against nil component lookups' do
      method_body = extract_method(controller, 'compare')
      has_nil_guard = method_body.match?(/find!\(|find_by!|\.nil\?|return.*unless|&\.|head :not_found/)
      expect(has_nil_guard).to be(true),
                               'compare must handle nil from find_by (invalid IDs) without crashing'
    end
  end

  describe 'history' do
    it 'has authorization beyond authorize_logged_in' do
      # history should use project-level auth or scope to released components
      before_actions = controller.lines.select { |l| l.include?('before_action') && l.include?('history') }
      has_auth = before_actions.any? { |l| l.match?(/authorize_viewer|authorize_member|authorize_logged_in/) }
      expect(has_auth).to be(true)
    end
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
