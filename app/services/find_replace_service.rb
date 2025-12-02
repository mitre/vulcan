# frozen_string_literal: true

##
# Service for find and replace operations within a component's rules
#
# Handles all text manipulation server-side for efficiency and consistency.
# Frontend only receives match metadata and calls replace endpoints.
#
# Usage:
#   service = FindReplaceService.new(component, 'sshd', fields: ['fixtext', 'check'])
#
#   # Find all matches
#   result = service.find
#   # => {
#   #      total_matches: 47,
#   #      total_rules: 12,
#   #      matches: [{ rule_id: 1, field: 'fixtext', instances: [...] }, ...]
#   #    }
#
#   # Replace single instance
#   result = service.replace_instance(rule_id: 1, field: 'fixtext', instance_index: 0, replacement: 'openssh')
#   # => { success: true, rule: {...} }
#
#   # Replace all matches
#   result = service.replace_all(replacement: 'openssh', audit_comment: 'Standardize naming')
#   # => { success: true, rules_updated: 12, matches_replaced: 47 }
#
class FindReplaceService
  # Fields that can be searched/replaced, mapped to their model paths
  SEARCHABLE_FIELDS = {
    'title' => { path: :title, nested: false },
    'fixtext' => { path: :fixtext, nested: false },
    'vendor_comments' => { path: :vendor_comments, nested: false },
    'status_justification' => { path: :status_justification, nested: false },
    'artifact_description' => { path: :artifact_description, nested: false },
    'check' => { path: :content, nested: :checks, association: :checks },
    'vuln_discussion' => { path: :vuln_discussion, nested: :disa_rule_descriptions, association: :disa_rule_descriptions },
    'mitigations' => { path: :mitigations, nested: :disa_rule_descriptions, association: :disa_rule_descriptions }
  }.freeze

  DEFAULT_FIELDS = SEARCHABLE_FIELDS.keys.freeze
  CONTEXT_CHARS = 80 # Characters of context around each match

  attr_reader :component, :search_text, :fields, :case_sensitive

  ##
  # Initialize the service
  #
  # @param component [Component] the component to search within
  # @param search_text [String] the text to find
  # @param fields [Array<String>] fields to search (default: all)
  # @param case_sensitive [Boolean] whether search is case-sensitive (default: false)
  #
  def initialize(component, search_text, fields: nil, case_sensitive: false)
    @component = component
    @search_text = search_text.to_s
    @fields = fields.present? ? (Array(fields) & DEFAULT_FIELDS) : DEFAULT_FIELDS
    @case_sensitive = case_sensitive
  end

  ##
  # Find all matches in the component's rules
  #
  # @return [Hash] with :total_matches, :total_rules, :matches
  #
  def find
    return empty_find_result if search_text.blank? || search_text.length < 2

    matches = []
    total_matches = 0

    rules_with_associations.each do |rule|
      rule_matches = find_in_rule(rule)
      next if rule_matches[:instances].empty?

      matches << rule_matches
      total_matches += rule_matches[:match_count]
    end

    {
      total_matches: total_matches,
      total_rules: matches.size,
      matches: matches
    }
  end

  ##
  # Replace a single instance of the search text
  #
  # @param rule_id [Integer] the rule to modify
  # @param field [String] the field containing the match
  # @param instance_index [Integer] which occurrence to replace (0-based)
  # @param replacement [String] the replacement text
  # @param audit_comment [String] comment for audit trail
  # @return [Hash] with :success, :rule, :error
  #
  def replace_instance(rule_id:, field:, instance_index:, replacement:, audit_comment: 'Find & Replace')
    rule = component.rules.find_by(id: rule_id)
    return { success: false, error: 'Rule not found' } unless rule
    return { success: false, error: 'Invalid field' } unless SEARCHABLE_FIELDS.key?(field)

    field_config = SEARCHABLE_FIELDS[field]
    current_value = get_field_value(rule, field_config)
    return { success: false, error: 'Field is empty' } if current_value.blank?

    # Find all instances in the current value
    instances = find_instances_in_text(current_value)
    return { success: false, error: 'Instance not found' } if instance_index >= instances.size

    # Replace just the specified instance
    instance = instances[instance_index]
    new_value = current_value.dup
    new_value[instance[:index], instance[:length]] = replacement

    # Update the field
    update_field_value(rule, field_config, new_value, audit_comment)

    { success: true, rule: rule.reload }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  ##
  # Replace all instances in a single field of a rule
  #
  # @param rule_id [Integer] the rule to modify
  # @param field [String] the field to update
  # @param replacement [String] the replacement text
  # @param audit_comment [String] comment for audit trail
  # @return [Hash] with :success, :rule, :replaced_count, :error
  #
  def replace_field(rule_id:, field:, replacement:, audit_comment: 'Find & Replace')
    rule = component.rules.find_by(id: rule_id)
    return { success: false, error: 'Rule not found' } unless rule
    return { success: false, error: 'Invalid field' } unless SEARCHABLE_FIELDS.key?(field)

    field_config = SEARCHABLE_FIELDS[field]
    current_value = get_field_value(rule, field_config)
    return { success: false, error: 'Field is empty' } if current_value.blank?

    # Replace all occurrences
    new_value, replaced_count = replace_all_in_text(current_value, replacement)
    return { success: false, error: 'No matches found' } if replaced_count.zero?

    # Update the field
    update_field_value(rule, field_config, new_value, audit_comment)

    { success: true, rule: rule.reload, replaced_count: replaced_count }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  ##
  # Replace all matches across all rules in the component
  #
  # @param replacement [String] the replacement text
  # @param audit_comment [String] comment for audit trail
  # @return [Hash] with :success, :rules_updated, :matches_replaced, :errors
  #
  def replace_all(replacement:, audit_comment: 'Find & Replace (all)')
    return { success: false, error: 'Search text required' } if search_text.blank?

    rules_updated = 0
    matches_replaced = 0
    errors = []

    ActiveRecord::Base.transaction do
      rules_with_associations.each do |rule|
        rule_replacements = 0

        fields.each do |field|
          field_config = SEARCHABLE_FIELDS[field]
          current_value = get_field_value(rule, field_config)
          next if current_value.blank?

          new_value, count = replace_all_in_text(current_value, replacement)
          next if count.zero?

          update_field_value(rule, field_config, new_value, audit_comment)
          rule_replacements += count
        end

        if rule_replacements.positive?
          rules_updated += 1
          matches_replaced += rule_replacements
        end
      end
    end

    {
      success: true,
      rules_updated: rules_updated,
      matches_replaced: matches_replaced,
      errors: errors
    }
  rescue StandardError => e
    { success: false, error: e.message, rules_updated: rules_updated, matches_replaced: matches_replaced }
  end

  ##
  # Undo the last Find & Replace operation on a rule
  #
  # Uses the audited gem to find the most recent audit with a Find & Replace comment
  # and reverts those changes.
  #
  # @param rule_id [Integer] the rule to undo changes on
  # @return [Hash] with :success, :rule, :reverted_fields, :error
  #
  def undo(rule_id:)
    rule = component.rules.find_by(id: rule_id)
    return { success: false, error: 'Rule not found' } unless rule

    # Find the most recent Find & Replace audit for this rule
    last_audit = rule.own_and_associated_audits
                     .where('comment LIKE ?', 'Find & Replace%')
                     .order(created_at: :desc)
                     .first

    return { success: false, error: 'Nothing to undo' } unless last_audit
    return { success: false, error: 'Cannot undo this type of change' } unless last_audit.action == 'update'

    # Get the record that was changed
    record = last_audit.auditable
    return { success: false, error: 'Record no longer exists' } unless record

    reverted_fields = []

    # Revert each changed field to its previous value
    last_audit.audited_changes.each do |field, values|
      next unless values.is_a?(Array) # Only process [old, new] changes

      old_value = values.first
      record[field] = old_value
      reverted_fields << field
    end

    return { success: false, error: 'No fields to revert' } if reverted_fields.empty?

    record.audit_comment = 'Find & Replace - Undo'
    record.save!

    { success: true, rule: rule.reload, reverted_fields: reverted_fields }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  private

  ##
  # Get rules with necessary associations preloaded
  #
  def rules_with_associations
    @rules_with_associations ||= component.rules
                                          .includes(:checks, :disa_rule_descriptions)
                                          .order(:rule_id)
  end

  ##
  # Find all matches within a single rule
  #
  def find_in_rule(rule)
    instances = []
    match_count = 0

    fields.each do |field|
      field_config = SEARCHABLE_FIELDS[field]
      value = get_field_value(rule, field_config)
      next if value.blank?

      field_instances = find_instances_in_text(value)
      next if field_instances.empty?

      instances << {
        field: field,
        instances: field_instances
      }
      match_count += field_instances.size
    end

    {
      rule_id: rule.id,
      rule_identifier: rule.rule_id,
      match_count: match_count,
      instances: instances
    }
  end

  ##
  # Find all instances of search_text in a string
  #
  # @param text [String] the text to search
  # @return [Array<Hash>] array of { index:, length:, text:, context: }
  #
  def find_instances_in_text(text)
    instances = []
    search_pattern = case_sensitive ? search_text : search_text.downcase
    search_target = case_sensitive ? text : text.downcase

    index = 0
    while (pos = search_target.index(search_pattern, index))
      # Extract the actual matched text (preserving original case)
      matched_text = text[pos, search_text.length]

      # Build context around match
      context_start = [0, pos - CONTEXT_CHARS].max
      context_end = [text.length, pos + search_text.length + CONTEXT_CHARS].min
      context = text[context_start...context_end]

      # Add ellipsis if truncated
      context = "...#{context}" if context_start.positive?
      context = "#{context}..." if context_end < text.length

      instances << {
        index: pos,
        length: search_text.length,
        text: matched_text,
        context: context
      }

      index = pos + 1
    end

    instances
  end

  ##
  # Replace all instances in text and return new text + count
  #
  def replace_all_in_text(text, replacement)
    if case_sensitive
      new_text = text.gsub(search_text, replacement)
      count = text.scan(search_text).size
    else
      pattern = Regexp.new(Regexp.escape(search_text), Regexp::IGNORECASE)
      count = text.scan(pattern).size
      new_text = text.gsub(pattern, replacement)
    end

    [new_text, count]
  end

  ##
  # Get field value from rule (handles nested associations)
  #
  def get_field_value(rule, field_config)
    if field_config[:nested]
      association = rule.send(field_config[:association])
      record = association.first
      return nil unless record

      record.send(field_config[:path])
    else
      rule.send(field_config[:path])
    end
  end

  ##
  # Update field value on rule (handles nested associations)
  #
  def update_field_value(rule, field_config, new_value, audit_comment)
    if field_config[:nested]
      association = rule.send(field_config[:association])
      record = association.first
      return unless record

      record.update!(field_config[:path] => new_value)
      rule.update!(audit_comment: audit_comment)
    else
      rule.update!(field_config[:path] => new_value, audit_comment: audit_comment)
    end
  end

  def empty_find_result
    { total_matches: 0, total_rules: 0, matches: [] }
  end
end
