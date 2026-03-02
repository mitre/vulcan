# frozen_string_literal: true

require 'rails_helper'

##
# Deny-by-default authorization safety net
#
# This spec introspects routes and controllers at test time and verifies
# every routable action is covered by at least one authorize_* before_action
# callback. This prevents new actions from being added without authorization.
#
# REQUIREMENT: Every controller action MUST have explicit authorization.
# authenticate_user! (Devise) handles AUTHENTICATION (who are you?).
# authorize_* methods handle AUTHORIZATION (what can you do?).
# Both are required — authentication alone is not sufficient.
#
# All recognized authorization callback method names.
# If you add a new authorize_* method, add it here.
AUTHORIZE_METHODS = %w[
  authorize_logged_in
  authorize_admin
  authorize_admin_or_create_permission_enabled
  authorize_admin_project
  authorize_review_project
  authorize_author_project
  authorize_viewer_project
  authorize_admin_component
  authorize_review_component
  authorize_author_component
  authorize_viewer_component
  authorize_admin_membership
  authorize_membership_create
  authorize_component_access
  authorize_compare_access
  authorize_section_lock
  check_admin_for_advanced_fields
  set_and_authorize_access_request
].freeze

# Route prefixes to skip — these are handled by Devise or Rails internals,
# not by our authorize_* methods.
SKIP_CONTROLLER_PREFIXES = %w[
  devise/
  sessions
  users/registrations
  users/omniauth_callbacks
  rails/
  active_storage/
  health_check/
  action_mailbox/
  consent
  api/version
].freeze

# Specific controller#action pairs that intentionally use authenticate_user!
# as their only authorization, with a documented reason for each.
AUTHENTICATE_ONLY_ACTIONS = {
  # Api::SearchController scopes ALL queries to current_user.available_projects.
  # Authorization is data-scoped (users only see what they have access to),
  # not action-scoped. Any authenticated user can search.
  'api/search#global' => 'Data-scoped auth via current_user.available_projects'
}.freeze

RSpec.describe 'Authorization coverage' do
  before do
    Rails.application.reload_routes!
  end

  it 'every routed action has an authorize_* before_action' do
    # Eager-load all controllers so descendants are populated
    Rails.application.eager_load!

    # Collect all routable controller#action pairs from the route table
    routed_actions = extract_routed_actions

    uncovered = []

    routed_actions.each do |controller_path, actions|
      # Skip Devise/Rails/framework controllers
      next if SKIP_CONTROLLER_PREFIXES.any? { |prefix| controller_path.start_with?(prefix) }

      # Resolve the controller class
      controller_class = resolve_controller(controller_path)
      next unless controller_class

      # Skip abstract base controllers
      next if controller_class == Api::BaseController

      # Get all before_action callbacks for this controller
      callbacks = controller_class._process_action_callbacks.select { |cb| cb.kind == :before }

      actions.each do |action|
        # Skip if explicitly documented as authenticate-only
        action_key = "#{controller_path}##{action}"
        next if AUTHENTICATE_ONLY_ACTIONS.key?(action_key)

        # Check if any authorize_* callback covers this action
        covered = callbacks.any? do |cb|
          next false unless AUTHORIZE_METHODS.include?(cb.filter.to_s)

          action_covered_by_callback?(cb, action)
        end

        uncovered << action_key unless covered
      end
    end

    expect(uncovered).to be_empty,
                         "The following routed actions have NO authorize_* before_action.\n" \
                         "Every action must have explicit authorization.\n\n" \
                         "To fix:\n  " \
                         "1. Add an appropriate authorize_* before_action to the controller, OR\n  " \
                         "2. Add to AUTHENTICATE_ONLY_ACTIONS with a documented reason\n\n" \
                         "Uncovered actions:\n#{uncovered.map { |a| "  - #{a}" }.join("\n")}"
  end

  private

  # Extract all controller#action pairs from the route table
  def extract_routed_actions
    result = {}
    Rails.application.routes.routes.each do |route|
      controller = route.defaults[:controller]
      action = route.defaults[:action]
      next if controller.blank? || action.blank?

      result[controller] ||= Set.new
      result[controller] << action
    end
    result
  end

  # Resolve a controller path (e.g., "components") to a controller class
  def resolve_controller(controller_path)
    "#{controller_path}_controller".classify.constantize
  rescue NameError
    nil
  end

  # Check if a callback covers a specific action, respecting :only/:except
  def action_covered_by_callback?(callback, action)
    only_actions = extract_action_filter(callback, :@if)
    except_actions = extract_action_filter(callback, :@unless)

    if only_actions
      only_actions.include?(action)
    elsif except_actions
      except_actions.exclude?(action)
    else
      # No :only or :except constraint — applies to all actions.
      # Note: callbacks with if:/unless: procs (conditional auth like
      # `if: -> { @component.released }`) still count as covered because
      # the authorization logic IS present for that action.
      true
    end
  end

  # Extract action names from ActionFilter conditions on a callback.
  # Rails stores :only as @if conditions and :except as @unless conditions
  # using AbstractController::Callbacks::ActionFilter objects.
  def extract_action_filter(callback, ivar)
    conditions = callback.instance_variable_get(ivar) || []
    filter = conditions.find { |c| c.is_a?(AbstractController::Callbacks::ActionFilter) }
    return nil unless filter

    filter.instance_variable_get(:@actions)&.to_a
  end
end
