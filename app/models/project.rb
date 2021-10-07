# frozen_string_literal: true

# Projects are home to a collection of Components and are managed by Users.
class Project < ApplicationRecord
  attr_accessor :current_user

  audited except: %i[id created_at updated_at project_members_count], max_audits: 1000

  has_many :project_members, -> { includes :user }, inverse_of: 'project', dependent: :destroy
  has_many :users, through: :project_members
  has_many :components, dependent: :destroy
  has_many :rules, through: :components
  has_one :project_metadata, dependent: :destroy
  accepts_nested_attributes_for :project_metadata, :project_members

  validates :name, presence: true

  scope :alphabetical, -> { order(:name) }

  # Helper method to extract data from Project Metadata
  def metadata
    project_metadata&.data
  end

  ##
  # Get a list of Users that are not yet members of this project
  #
  def available_members
    (User.all.select(:id, :name, :email) - users.select(:id, :name, :email))
  end

  ##
  # Get a list of projects that can be added as components to this project
  def available_components
    # Don't allow importing a component twice to the same project
    reject_component_ids = components.pluck(:id, :component_id).flatten.compact

    components = Component.where(released: true).where.not(id: reject_component_ids)
    # Trim down to only the user's viewable projects if `current_user` is present
    if current_user && !current_user.admin
      project_memberships = ProjectMember.where(user_id: current_user.id).pluck(:project_id)
      components = components.where(project_id: project_memberships)
    end
    components
  end
end
