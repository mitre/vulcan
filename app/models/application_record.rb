# frozen_string_literal: true

# This is the base model for the application. Things should only be
# placed here if they are shared between multiple models
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
