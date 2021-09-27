# frozen_string_literal: true

# Projects are home to a collection of Rules and are managed by Users.
class Project < ApplicationRecord
  audited except: %i[id created_at updated_at project_members_count], max_audits: 1000

  belongs_to :based_on, lambda {
                          select(:srg_id, :title, :version)
                        },
             class_name: :SecurityRequirementsGuide,
             foreign_key: 'security_requirements_guide_id',
             inverse_of: 'projects'
  has_many :project_members, dependent: :destroy
  has_many :users, through: :project_members
  has_many :rules, dependent: :destroy
  has_one :project_metadata, dependent: :destroy
  accepts_nested_attributes_for :project_metadata, :rules

  validates_with PrefixValidator

  validates :name, :prefix, :based_on, presence: true

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

  ##
  # Override `as_json` to include dependent records
  #
  def as_json(options = {})
    super.merge(
      {
        histories: histories,
        admins: users.where(project_members: { role: :admin }),
        metadata: project_metadata&.data,
        project_members: project_members.includes(:user).alphabetical,
        based_on: based_on.full_title
      }
    )
  end

  ##
  # Get a list of Users that are not yet members of this project
  #
  def available_members
    (User.all.select(:id, :name, :email) - users.select(:id, :name, :email))
  end
end
