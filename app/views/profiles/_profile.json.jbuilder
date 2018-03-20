json.extract! profile, :id, :name, :title, :maintainer, :copyright, :copyright_email, :license, :summary, :version, :sha256, :created_at, :updated_at
json.url profile_url(profile, format: :json)
