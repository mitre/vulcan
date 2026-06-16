# frozen_string_literal: true

desc 'Fix rules with satisfied_by relationships that are not in ADNM status. ' \
     'Uses update_columns to bypass callbacks (safe on v2.3.7 with buggy before_save). ' \
     'Set DRY_RUN=1 to preview changes without applying. ' \
     'Set COMPONENT_ID=N to scope to a single component. ' \
     'Set LIMIT=1 to fix only the first match (for testing).'
task fix_adnm_status: :environment do
  dry_run = ENV['DRY_RUN'] == '1'
  component_id = ENV['COMPONENT_ID']&.to_i
  limit = ENV['LIMIT']&.to_i

  puts dry_run ? '=== DRY RUN — no changes will be made ===' : '=== LIVE RUN ==='
  puts ''

  scope = Rule.joins(:satisfied_by)
              .where.not(status: RuleConstants::STATUS_APPLICABLE_DNM)
              .where(deleted_at: nil)
              .includes(:component, :satisfied_by)

  scope = scope.where(component_id: component_id) if component_id
  scope = scope.limit(limit) if limit

  rules = scope.to_a
  puts "Found #{rules.size} rules needing ADNM status fix"
  puts ''

  fixed = 0
  errors = 0

  rules.each do |rule|
    parent = rule.satisfied_by.first
    next unless parent

    parent_label = "#{parent.component.prefix}-#{parent.rule_id}"
    parent_title = parent.title.presence || parent_label
    old_status = rule.status

    justification = "This requirement is addressed by #{parent_label} (#{parent_title})."
    mitigation = "This requirement is fully mitigated by #{parent_label}. " \
                 'With the implementation of this mitigation, the overall risk is fully mitigated.'

    puts "#{rule.component.prefix}-#{rule.rule_id} | #{old_status} → ADNM | parent: #{parent_label}"

    next if dry_run

    begin
      Rule.transaction do
        # rubocop:disable Rails/SkipsModelValidations -- intentional: bypass v2.3.7 buggy callbacks
        rule.update_columns(
          status: RuleConstants::STATUS_APPLICABLE_DNM,
          status_justification: justification
        )

        drd = rule.disa_rule_descriptions.first
        if drd
          drd.update_columns(mitigations: mitigation)
        # rubocop:enable Rails/SkipsModelValidations
        else
          DisaRuleDescription.create!(
            rule: rule,
            mitigations: mitigation
          )
        end
      end
      fixed += 1
    rescue StandardError => e
      puts "  ERROR: #{e.message}"
      errors += 1
    end
  end

  puts ''
  puts '=== Summary ==='
  puts "Total found: #{rules.size}"
  puts "Fixed: #{fixed}" unless dry_run
  puts "Errors: #{errors}" unless dry_run
  puts '(DRY RUN — no changes made)' if dry_run
end
