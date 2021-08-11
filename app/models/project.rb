# frozen_string_literal: true

# Projects are home to a collection of Rules and are managed by Users.
class Project < ApplicationRecord
  has_many :project_members, dependent: :destroy
  has_many :users, through: :project_members
  has_many :rules, dependent: :destroy

  ##
  # Get a list of Users that are not yet members of this project
  #
  def available_members
    User.all - project_members.map(&:user)
  end
end
