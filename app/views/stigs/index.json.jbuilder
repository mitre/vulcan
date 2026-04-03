# frozen_string_literal: true

# Optimized JSON for STIGs index (table view)
# Only includes fields needed for table display, excludes heavy associations

json.array! @stigs, cached: true do |stig|
  json.id stig.id
  json.stig_id stig.stig_id
  json.title stig.title
  json.version stig.version
  json.benchmark_date stig.benchmark_date

  # Severity counts (virtual columns from with_severity_counts scope)
  json.severity_counts do
    json.high stig.severity_high_count
    json.medium stig.severity_medium_count
    json.low stig.severity_low_count
  end
end
