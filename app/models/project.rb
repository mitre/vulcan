# frozen_string_literal: true

# Projects are home to a collection of Rules and are managed by Users.
class Project < ApplicationRecord
  audited except: %i[id created_at updated_at project_members_count], max_audits: 1000

  has_many :project_members, dependent: :destroy
  has_many :users, through: :project_members
  has_many :rules, dependent: :destroy
  has_one :project_metadata, dependent: :destroy
  accepts_nested_attributes_for :project_metadata

  scope :alphabetical, -> { order(:name) }

  ##
  # Override `as_json` to include dependent records
  #
  def as_json(options = {})
    super.merge(
      {
        histories: histories,
        admins: users.where(project_members: { role: :admin }),
        metadata: project_metadata&.data,
        project_members: project_members.includes(:user).alphabetical
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
