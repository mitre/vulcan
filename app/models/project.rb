# frozen_string_literal: true

# Projects are home to a collection of Rules and are managed by Users.
class Project < ApplicationRecord
  attr_accessor :current_user

  audited except: %i[
    id
    created_at
    updated_at
    project_members_count
    in_development_rule_count
    under_review_rule_count
    locked_rule_count
  ], max_audits: 1000

  belongs_to :based_on, lambda {
                          select(:srg_id, :title, :version)
                        },
             class_name: :SecurityRequirementsGuide,
             foreign_key: 'security_requirements_guide_id',
             inverse_of: 'projects',
             optional: true
  has_many :project_members, -> { includes :user }, inverse_of: 'project', dependent: :destroy
  has_many :users, through: :project_members
  has_many :rules, dependent: :destroy
  has_one :project_metadata, dependent: :destroy
  accepts_nested_attributes_for :project_metadata, :rules, :project_members

  # Expect rules to touch the project when they are updated
  after_touch :update_rule_status_counters

  validates_with PrefixValidator, if: -> { prefix.present? }

  validates :name, presence: true

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
  scope :components, -> { where.not(security_requirements_guide_id: nil) }
  scope :projects, -> { where(security_requirements_guide_id: nil) }

  # Benchmark: parsed XML (Xccdf::Benchmark.parse(xml))
  def self.from_mapping(benchmark, project_id)
    rule_models = benchmark.rule.map do |rule|
      Rule.from_mapping(rule, project_id)
    end

    # Examine import results for failures
    import_result = Rule.import(rule_models, all_or_none: true, recursive: true).failed_instances.blank?
    # rubocop:disable Rails/SkipsModelValidations
    Project.find(project_id).touch
    # rubocop:enable Rails/SkipsModelValidations
    import_result
  end

  def prefix=(val)
    self[:prefix] = val.upcase
  end

  def as_json(options = {})
    super(options).merge({ component: component? })
  end

  # Helper that tells if the project is a component
  # Right now this is very simlple, but may become more complicated in the future
  def component?
    security_requirements_guide_id.present?
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
    # Components cannot contain components
    return [] if component? || current_user.nil?

    projects = current_user.available_projects
                           .components
                           .alphabetical
                           .where.not(id: component_projects.pluck(:child_project_id))
    projects.pluck(:id).map { |pid| Component.new(project_id: id, child_project_id: pid) }
  end

  private

  def update_rule_status_counters
    # Projects are not expected to have rules
    return unless component?

    sql_counts = rules.group('review_requestor_id IS NOT NULL', :locked).count
    update(
      in_development_rule_count: sql_counts[[false, false]] || 0,
      under_review_rule_count: sql_counts[[true, false]] || 0,
      locked_rule_count: sql_counts[[false, true]] || 0
    )
  end
end
