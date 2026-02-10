# frozen_string_literal: true

# Optimized JSON for Components index (table view)
# Only includes fields needed for table display, excludes heavy associations

json.array! @components_json do |component|
  json.id component.id
  json.name component.name
  json.prefix component.prefix
  json.version component.version
  json.release component.release
  json.updated_at component.updated_at

  # Based on SRG info (eager loaded)
  json.based_on_title component.based_on.title
  json.based_on_version component.based_on.version

  # Severity counts (virtual columns from with_severity_counts scope)
  json.severity_counts do
    json.high component.severity_high_count
    json.medium component.severity_medium_count
    json.low component.severity_low_count
  end
end
