json.extract! srg_control, :id, :controlId, :severity, :title, :description, :nistFamilies, :ruleID, :fixid, :fixtext, :checkid, :checktext, :created_at, :updated_at
json.url srg_control_url(srg_control, format: :json)
