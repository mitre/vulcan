# frozen_string_literal: true

# Serializes ProjectAccessRequest with nested user and project.
# Replaces hand-built hashes in ApplicationController and ProjectBlueprint.
class ProjectAccessRequestBlueprint < Blueprinter::Base
  identifier :id

  association :user, blueprint: UserBlueprint

  field :project do |ar, _options|
    { 'id' => ar.project.id, 'name' => ar.project.name }
  end
end
