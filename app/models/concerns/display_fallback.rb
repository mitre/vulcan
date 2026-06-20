# frozen_string_literal: true

# DisplayFallback implements the "prefer the rule's own value, fall back to the
# SRG template" pattern central to the DB 3NF redesign
# (docs/plans/DATABASE-COMPLETE-REDESIGN-v2.md, Phase 1).
#
# A Rule starts life as a copy of its SRG template. As later phases stop copying
# template content, a rule's own column may be NULL — meaning "unchanged from the
# template." These display_* methods resolve that transparently so views,
# blueprints, and exports never need to know whether a value was customized.
#
# Resolution order for every field:
#   1. the rule's own column value (a user override), if present
#   2. an explicit `<field>_override` accessor, if the model defines one (Phase 3)
#   3. the SRG template value via the :srg_rule association
#
# Always load collections through `.with_display_fallbacks` to avoid an N+1 on
# :srg_rule when calling display_* over many rules.
module DisplayFallback
  extend ActiveSupport::Concern

  # Fields whose canonical value may live on the SRG template.
  OVERRIDABLE_FIELDS = %i[title fixtext ident rule_severity].freeze

  included do
    scope :with_display_fallbacks, -> { includes(:srg_rule) }
  end

  def display_title
    display_field(:title)
  end

  def display_fixtext
    display_field(:fixtext)
  end

  def display_ident
    display_field(:ident)
  end

  def display_severity
    display_field(:rule_severity)
  end

  # Generic resolver. Reads the rule's own attribute first, then an optional
  # `<field>_override` accessor (added in Phase 3), then the SRG template.
  #
  # Uses respond_to? guards rather than `rescue nil` so a genuine programming
  # error (e.g. a typo'd field) surfaces instead of being silently swallowed.
  def display_field(field)
    own = self[field] if has_attribute?(field.to_s)
    return own if own.respond_to?(:presence) ? own.presence : own

    override_method = "#{field}_override"
    if respond_to?(override_method, true)
      override = public_send(override_method)
      return override if override.present?
    end

    return nil unless srg_rule.respond_to?(field)

    srg_rule.public_send(field)
  end

  # True if any overridable field diverges from the SRG template.
  def has_overrides?
    return false if srg_rule.nil?

    OVERRIDABLE_FIELDS.any? do |field|
      own = self[field]
      own.present? && own != srg_rule.public_send(field)
    end
  end

  # Compact description of what this rule customizes from its template.
  def override_summary
    {
      rule_id: id,
      srg_requirement: srg_rule&.version,
      overridden: OVERRIDABLE_FIELDS.index_with do |field|
        own = self[field]
        own.present? && srg_rule.present? && own != srg_rule.public_send(field)
      end
    }
  end
end
