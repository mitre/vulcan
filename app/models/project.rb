# frozen_string_literal: true

# Projects are home to a collection of Components and are managed by Users.
class Project < ApplicationRecord
  attr_accessor :current_user

  enum :visibility, { discoverable: 0, hidden: 1 }

  audited except: %i[id admin_name admin_email memberships_count created_at updated_at], max_audits: 1000

  has_many :memberships, -> { includes :user }, as: :membership, inverse_of: :membership, dependent: :destroy
  has_many :users, through: :memberships
  has_many :components, dependent: :destroy
  has_many :rules, through: :components
  has_many :access_requests, class_name: 'ProjectAccessRequest', dependent: :destroy
  has_one :project_metadata, dependent: :destroy
  accepts_nested_attributes_for :project_metadata, :memberships

  validates :name, presence: true

  scope :alphabetical, -> { order(:name) }

  # Helper method to extract data from Project Metadata
  def metadata
    project_metadata&.data
  end

  def admins
    memberships.where(
      role: 'admin'
    ).eager_load(:user).select(:user_id, :name, :email)
  end

  def update_admin_contact_info
    project_admin = admins.first
    if project_admin
      self.admin_name = project_admin.name
      self.admin_email = project_admin.email
    else
      self.admin_name = nil
      self.admin_email = nil
    end
    save
    components.each(&:update_admin_contact_info)
  end

  ##
  # Get a list of Users that are not yet members of this project
  # Returns empty array to prevent email enumeration vulnerability
  # Admins should add members directly via user search or invitation
  #
  def available_members
    # SECURITY: Don't expose all registered users' emails
    # Return empty array - use admin-only user search instead
    []
  end

  def details
    {
      ac: rules.where(status: 'Applicable - Configurable').size,
      aim: rules.where(status: 'Applicable - Inherently Meets').size,
      adnm: rules.where(status: 'Applicable - Does Not Meet').size,
      na: rules.where(status: 'Not Applicable').size,
      nyd: rules.where(status: 'Not Yet Determined').size,
      nur: rules.where(locked: false).where(review_requestor_id: nil).size,
      ur: rules.where(locked: false).where.not(review_requestor_id: nil).size,
      lck: rules.where(locked: true).size,
      total: rules.size
    }
  end

  ##
  # Get a list of projects that can be added as components to this project
  def available_components
    # Don't allow importing a component twice to the same project
    reject_component_ids = components.pluck(:id, :component_id).flatten.compact
    # Assumption that released components are publicly available within vulcan
    Component.where(released: true).where.not(id: reject_component_ids)
  end
end
