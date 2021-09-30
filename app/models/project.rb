# frozen_string_literal: true

# Projects are home to a collection of Rules and are managed by Users.
class Project < ApplicationRecord
  attr_accessor :current_user

  audited except: %i[id created_at updated_at project_members_count], max_audits: 1000

  belongs_to :based_on, lambda {
                          select(:srg_id, :title, :version)
                        },
             class_name: :SecurityRequirementsGuide,
             foreign_key: 'security_requirements_guide_id',
             inverse_of: 'projects'
  has_many :project_members, -> { includes :user }, inverse_of: 'project', dependent: :destroy
  has_many :users, through: :project_members
  has_many :rules, dependent: :destroy
  has_one :project_metadata, dependent: :destroy
  accepts_nested_attributes_for :project_metadata, :rules, :project_members

  validates_with PrefixValidator

  validates :name, :prefix, :based_on, presence: true

  has_many :components, dependent: :destroy
  has_many :component_projects, through: :components, source: :child_project

  has_many :parent_components,
           foreign_key: :child_project_id,
           class_name: 'Component',
           inverse_of: :child_project,
           dependent: :destroy
  has_many :parent_projects, through: :parent_components, source: :project

  accepts_nested_attributes_for :project_metadata

  scope :alphabetical, -> { order(:name) }

  # Benchmark: parsed XML (Xccdf::Benchmark.parse(xml))
  def self.from_mapping(benchmark, project_id)
    rule_models = benchmark.rule.map do |rule|
      Rule.from_mapping(rule, project_id)
    end
    # Examine import results for failures
    Rule.import(rule_models, all_or_none: true, recursive: true).failed_instances.blank?
  end

  def prefix=(val)
    self[:prefix] = val.upcase
  end

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
    return [] unless Component.where(child_project_id: id).count.zero?

    projects = Project.where.not(
      id: [id] + component_projects.pluck(:child_project_id) + Component.pluck(:project_id)
    )
    # If there is a current user and they are not an admin,
    # then we should filter down to only the projects that they are a member of.
    if current_user && !current_user.admin
      allowed_project_ids = ProjectMember.where(user_id: current_user.id).pluck(:id)
      projects = projects.where(id: allowed_project_ids)
    end
    projects.pluck(:id).map { |pid| Component.new(project_id: id, child_project_id: pid) }
  end
end
