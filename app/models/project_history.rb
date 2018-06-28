class ProjectHistory < ApplicationRecord
  resourcify
  belongs_to :project, :inverse_of => :project_histories
  belongs_to :user, :inverse_of => :project_histories
end
