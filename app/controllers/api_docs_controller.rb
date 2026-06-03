# frozen_string_literal: true

class ApiDocsController < ApplicationController
  def show; end

  def spec
    spec_path = Rails.root.join('doc/openapi.yaml')
    send_file spec_path, type: 'application/yaml', disposition: 'inline'
  end
end
