# frozen_string_literal: true

# Optimized JSON for SRGs index (table view)
# Only includes fields needed for table display, excludes heavy associations

json.array! @srgs do |srg|
  json.id srg.id
  json.srg_id srg.srg_id
  json.title srg.title
  json.version srg.version
  json.release_date srg.release_date

  # Severity counts (virtual columns from with_severity_counts scope)
  json.severity_counts do
    json.high srg.severity_high_count
    json.medium srg.severity_medium_count
    json.low srg.severity_low_count
  end
end
