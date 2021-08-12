# frozen_string_literal: true

# Comments are discussions about Rules
class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :rule

  delegate :name, to: :user

  ##
  # Override `as_json` to include delegated attributes
  #
  def as_json(options = {})
    super options.merge(methods: %i[name])
  end
end
