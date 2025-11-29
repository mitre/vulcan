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

  # Project-level rule statistics - single SQL query
  def details
    # Use single query with FILTER for all counts
    sql = <<-SQL.squish
      SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'Applicable - Configurable') as ac,
        COUNT(*) FILTER (WHERE status = 'Applicable - Inherently Meets') as aim,
        COUNT(*) FILTER (WHERE status = 'Applicable - Does Not Meet') as adnm,
        COUNT(*) FILTER (WHERE status = 'Not Applicable') as na,
        COUNT(*) FILTER (WHERE status = 'Not Yet Determined') as nyd,
        COUNT(*) FILTER (WHERE locked = false AND review_requestor_id IS NULL) as nur,
        COUNT(*) FILTER (WHERE locked = false AND review_requestor_id IS NOT NULL) as ur,
        COUNT(*) FILTER (WHERE locked = true) as lck
      FROM base_rules
      WHERE component_id IN (SELECT id FROM components WHERE project_id = #{id})
        AND deleted_at IS NULL
        AND type = 'Rule'
    SQL

    result = ActiveRecord::Base.connection.execute(sql).first
    {
      ac: result['ac'].to_i,
      aim: result['aim'].to_i,
      adnm: result['adnm'].to_i,
      na: result['na'].to_i,
      nyd: result['nyd'].to_i,
      nur: result['nur'].to_i,
      ur: result['ur'].to_i,
      lck: result['lck'].to_i,
      total: result['total'].to_i
    }
  end

  # Returns components with pre-computed summaries (2 SQL queries total)
  # This bypasses Component's as_json to avoid N+1 queries
  def components_with_summaries
    component_ids = components.pluck(:id)
    summaries = Component.batch_rules_summary(component_ids)

    components.includes(:based_on, :additional_questions).map do |component|
      summary = summaries[component.id] || empty_rules_summary
      total = summary[:total] || 0
      locked = summary[:locked] || 0

      # Build JSON directly without triggering Component's as_json computed methods
      {
        'id' => component.id,
        'name' => component.name,
        'version' => component.version,
        'release' => component.release,
        'title' => component.title,
        'description' => component.description,
        'prefix' => component.prefix,
        'released' => component.released,
        'rules_count' => component.rules_count,
        'admin_name' => component.admin_name,
        'admin_email' => component.admin_email,
        'project_id' => component.project_id,
        'security_requirements_guide_id' => component.security_requirements_guide_id,
        'component_id' => component.component_id,
        'created_at' => component.created_at,
        'updated_at' => component.updated_at,
        # Pre-computed values
        'based_on_title' => component.based_on&.title,
        'based_on_version' => component.based_on&.version,
        'additional_questions' => component.additional_questions.as_json,
        'releasable' => component.released_was ? false : (locked == total && total.positive?),
        'rules_summary' => summary,
        'parent_rules_count' => summary[:nested_count] || 0,
        'primary_controls_count' => summary[:primary_count] || 0
      }
    end
  end

  def empty_rules_summary
    {
      total: 0, primary_count: 0, nested_count: 0, locked: 0,
      under_review: 0, not_under_review: 0, changes_requested: 0,
      not_yet_determined: 0, applicable_configurable: 0,
      applicable_inherently_meets: 0, applicable_does_not_meet: 0, not_applicable: 0
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
