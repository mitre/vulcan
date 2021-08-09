# frozen_string_literal: true

# Comments are discussions about Rules
class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :rule
end
