# frozen_string_literal: true

# Projects are home to a collection of Rules and are managed by Users.
class Project < ApplicationRecord
  audited except: %i[id created_at updated_at project_members_count], max_audits: 1000

  has_many :project_members, dependent: :destroy
  has_many :users, through: :project_members
  has_many :rules, dependent: :destroy

  scope :alphabetical, -> { order(:name) }

  ##
  # Get a list of Users that are not yet members of this project
  #
  def available_members
    (User.all.select(:id, :email) - users.select(:id, :email))
  end
end
