# frozen_string_literal: true

# Serializes AdditionalAnswer for rule editor forms.
class AdditionalAnswerBlueprint < Blueprinter::Base
  identifier :id

  fields :additional_question_id, :answer
end
