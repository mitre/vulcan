json.extract! project, :id, :name, :title, :maintainer, :copyright, :copyright_email, :license, :summary, :version, :sha256, srgs:, :created_at, :updated_at
json.url project_url(project, format: :json)
