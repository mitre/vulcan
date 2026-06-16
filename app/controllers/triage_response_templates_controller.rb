# frozen_string_literal: true

##
# CRUD for project-scoped triage response templates.
# Viewer+ on the project can list (read), admins manage (write).
class TriageResponseTemplatesController < ApplicationController
  before_action :set_project
  before_action :authorize_viewer_project, only: %i[index]
  before_action :authorize_admin_project, only: %i[create update destroy]
  before_action :set_template, only: %i[update destroy]

  record_invalid_titles(
    create: 'Could not save template.',
    update: 'Could not update template.'
  )

  def index
    render json: {
      triage_response_templates: @project.triage_response_templates.for_project(@project).map { |t| serialize(t) }
    }
  end

  def create
    template = @project.triage_response_templates.new(template_params.merge(created_by: current_user))
    if template.save
      render json: { triage_response_template: serialize(template) }, status: :created
    else
      render_toast(title: 'Could not save template.', message: template.errors.full_messages)
    end
  end

  def update
    if @template.update(template_params)
      render json: { triage_response_template: serialize(@template) }
    else
      render_toast(title: 'Could not update template.', message: @template.errors.full_messages)
    end
  end

  def destroy
    @template.destroy!
    head :no_content
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_template
    @template = @project.triage_response_templates.find(params[:id])
  end

  def template_params
    params.expect(triage_response_template: %i[name body])
  end

  def serialize(template)
    {
      id: template.id,
      name: template.name,
      body: template.body,
      created_by_id: template.created_by_id,
      created_at: template.created_at
    }
  end
end
