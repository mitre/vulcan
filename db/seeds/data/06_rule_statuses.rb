# frozen_string_literal: true

# rubocop:disable Rails/Output, Rails/SkipsModelValidations
puts 'Setting varied rule statuses for demo coverage...'

container_component = Component.joins(:project)
                               .find_by(name: 'Container Platform', projects: { name: 'Container Platform' })

if container_component
  rules = container_component.rules.order(:rule_id).limit(6).to_a
  rule_e = rules[4]
  rule_f = rules[5]

  rule_e&.update_columns(status: 'Applicable - Configurable') if rule_e&.status != 'Applicable - Configurable'
  rule_f&.update_columns(status: 'Not Applicable') if rule_f&.status != 'Not Applicable'

  puts "  Container Platform: #{rules.size} rules, statuses set (4 NYD, 1 AC, 1 NA)"
else
  puts '  No Container Platform component — skipping rule status setup'
end
# rubocop:enable Rails/Output, Rails/SkipsModelValidations
