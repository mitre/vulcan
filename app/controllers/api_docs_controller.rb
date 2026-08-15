# frozen_string_literal: true

# Serves the machine-readable OpenAPI specification at the recommended root
# filenames, /openapi.yaml and /openapi.json. The browsable API reference
# lives inside the built documentation site under /docs/api.
class ApiDocsController < ApplicationController
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
