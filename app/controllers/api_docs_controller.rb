# frozen_string_literal: true

# Serves the browsable Scalar API docs page (show) and the OpenAPI spec
# (spec). Routed via GET /api-docs and /api-docs/openapi.yaml.
class ApiDocsController < ApplicationController
  def show; end

  def spec
    spec_path = Rails.root.join('doc/openapi.yaml')
    send_file spec_path, type: 'application/yaml', disposition: 'inline'
  end

  def spec_json
    yaml_content = Rails.root.join('doc/openapi.yaml').read
    json_content = YAML.safe_load(yaml_content, permitted_classes: [Date, Time]).to_json
    render json: json_content, content_type: 'application/json'
  end
end
