# frozen_string_literal: true

# The relocation proposal API. Source side: authors mark an authored SRG
# requirement for relocation (create an open proposal) and un-mark it
# while open (destroy). Receiving side: authors of the TARGET component
# adjudicate — dry-run preview, accept (lands the move), or decline with
# a required rationale (retained, visible to the source author). The
# mark itself carries source consent, so adjudication needs no
# source-side rights. Adjudicated records are terminal: the open-only
# lookup answers 404 for them, identical to a true miss. The backlog
# serves open proposals plus retained declines, scoped to projects the
# caller can see.
class RequirementRelocationsController < ApplicationController
  before_action :authorize_logged_in, only: %i[index]
  before_action :set_source_rule_component, only: %i[create]
  before_action :set_open_proposal, only: %i[destroy dry_run accept decline]
  # Un-marking is the source author's withdrawal — source-side authority.
  before_action :authorize_author_component, only: %i[create destroy]
  # Adjudication writes into (or refuses for) the target component —
  # TARGET-side author authority only. Re-pointing @component makes the
  # denial disclose (403 vs concealed 404) per the TARGET's own policy.
  before_action :set_target_component, only: %i[dry_run accept decline]
  before_action :authorize_author_target, only: %i[dry_run accept decline]

  def index
    rows = RequirementRelocation.unexecuted
                                .joins(source_rule: :component)
                                .where(components: { project_id: current_user.available_projects })
                                .includes(:requested_by, :declined_by, source_rule: :component)
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
    render_toast(title: 'Relocation proposal withdrawn.',
                 message: 'The requirement is no longer proposed for relocation.',
                 variant: 'success', status: :ok)
  end

  # Zero-write preview of exactly what accept would do.
  def dry_run
    render json: RelocationExecutor.new(@relocation, target_component: @target_component).dry_run
  end

  def accept
    RelocationExecutor.new(@relocation, target_component: @target_component,
                                        accepted_by: current_user).execute!
    render_toast(title: 'Proposal accepted.',
                 message: "Moved to #{@target_component.name} — the source requirement is now history.",
                 variant: 'success', status: :ok)
  rescue RelocationExecutor::ExecutionError => e
    render json: {
      toast: Toast.new(title: 'Could not accept the proposal.',
                       message: e.message.split('; '),
                       variant: 'danger')
    }, status: :unprocessable_content
  end

  def decline
    # Adjudication binds to an ELIGIBLE receiver: the same one eligibility
    # oracle accept uses (SRG kind, not released, not the source, family
    # declared) decides whether the named component may adjudicate at all —
    # an author of an unrelated component cannot terminate someone else's
    # proposal.
    eligibility_errors = RelocationExecutor.new(@relocation, target_component: @target_component)
                                           .validation_errors
    if eligibility_errors.any?
      return render json: {
        toast: Toast.new(title: 'Could not decline the proposal.',
                         message: eligibility_errors,
                         variant: 'danger')
      }, status: :unprocessable_content
    end

    if @relocation.update(decline_params.merge(declined_by: current_user, declined_at: Time.current))
      render_toast(title: 'Proposal declined.',
                   message: 'The source author can see your rationale in the backlog.',
                   variant: 'success', status: :ok)
    else
      render json: {
        toast: Toast.new(title: 'Could not decline the proposal.',
                         message: @relocation.errors.full_messages,
                         variant: 'danger')
      }, status: :unprocessable_content
    end
  end

  private

  def relocation_params
    params.expect(requirement_relocation: [:target_technology_token])
  end

  def decline_params
    params.expect(requirement_relocation: [:adjudication_rationale])
  end

  # The source must be an authored SrgRule with a component — a catalog
  # row (no component) answers exactly like a missing id.
  def set_source_rule_component
    @source_rule = SrgRule.find_by(id: params[:rule_id])
    @component = @source_rule&.component
    return if @component.present?

    render_resource_not_found
  end

  # Open-proposal-only lookup: an adjudicated record (declined or
  # executed) is terminal, so it answers byte-identically to a record
  # that never existed.
  def set_open_proposal
    @relocation = RequirementRelocation.proposed.find_by(id: params[:id])
    @component = @relocation&.component
    return if @component.present?

    render_resource_not_found
  end

  def set_target_component
    @target_component = Component.find_by(id: params[:target_component_id])
    return if @target_component.present?

    render_resource_not_found
  end

  def authorize_author_target
    @component = @target_component
    authorize_author_component
  end
end
