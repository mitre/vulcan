# frozen_string_literal: true

# This is the base model for the application. Things should only be
# placed here if they are shared between multiple models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ##
  # Build a structure that minimally describes the editing history of a model
  # and describes what can be reverted for that model.
  #
  # If `limit` is `nil`, then no limit will be applied on the number of histories returned
  #
  def histories(limit = 20)
    return unless defined?(own_and_associated_audits)

    own_and_associated_audits.order(:created_at).limit(limit).map(&:format)
  end
end
