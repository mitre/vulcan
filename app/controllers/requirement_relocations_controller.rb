# frozen_string_literal: true

# The relocation marker API: authors mark an authored SRG requirement for
# relocation (create a pending record), un-mark it (destroy the pending
# record), and anyone signed in reads the per-family backlog scoped to
# projects they can see. Executed records are never reachable here — the
# pending-only lookup answers 404 for them, identical to a true miss.
class RequirementRelocationsController < ApplicationController
  before_action :authorize_logged_in, only: %i[index]
  before_action :set_source_rule_component, only: %i[create]
  before_action :set_pending_relocation_component, only: %i[destroy]
  before_action :authorize_author_component, only: %i[create destroy]

  def index
    rows = RequirementRelocation.pending
                                .joins(source_rule: :component)
                                .where(components: { project_id: current_user.available_projects })
                                .includes(:requested_by, source_rule: :component)
                                .order(:created_at)
    rows = rows.where(target_technology_token: params[:target_technology_token]) if params[:target_technology_token].present?

    render body: RequirementRelocationBlueprint.render(rows), content_type: 'application/json'
  end

  def create
    relocation = RequirementRelocation.new(relocation_params.merge(source_rule_id: @source_rule.id,
                                                                   requested_by: current_user))
    if relocation.save
      render_toast(title: 'Requirement marked for relocation.',
                   message: "Marked for the #{relocation.target_technology_token} family.",
                   variant: 'success', status: :ok)
    else
      render json: {
        toast: Toast.new(title: 'Could not mark requirement for relocation.',
                         message: relocation.errors.full_messages,
                         variant: 'danger')
      }, status: :unprocessable_content
    end
  end

  def destroy
    @relocation.destroy!
    render_toast(title: 'Relocation marker removed.',
                 message: 'The requirement is no longer marked for relocation.',
                 variant: 'success', status: :ok)
  end

  private

  def relocation_params
    params.expect(requirement_relocation: [:target_technology_token])
  end

  # The source must be an authored SrgRule with a component — a catalog
  # row (no component) answers exactly like a missing id.
  def set_source_rule_component
    @source_rule = SrgRule.find_by(id: params[:rule_id])
    @component = @source_rule&.component
    return if @component.present?

    render_resource_not_found
  end

  # Pending-only lookup: an executed record is immutable to users, so it
  # answers byte-identically to a record that never existed.
  def set_pending_relocation_component
    @relocation = RequirementRelocation.pending.find_by(id: params[:id])
    @component = @relocation&.component
    return if @component.present?

    render_resource_not_found
  end
end
