# frozen_string_literal: true

# The BaseRule class is a simple class shared between SRG Rules and regular Component Rules.
# SRG Rules belong to an SRG, Component rules belong to a component and a SRG Rule
class BaseRule < ApplicationRecord
  amoeba do
    include_association :rule_descriptions
    include_association :disa_rule_descriptions
    include_association :checks
    include_association :references
    propagate
  end

  include RuleConstants
  include CciMap::Constants

  # Canonical DISA display order for a rule collection: by `version` (the
  # STIG-ID / SRG-ID — DISA's published document order, zero-padded so a
  # lexical sort equals the canonical order), then `rule_id`, with `id` as the
  # unique tiebreaker so the ordering is a deterministic TOTAL order (a
  # non-unique key alone still leaves ties non-deterministic). Mirrors the
  # export path (Export::Base uses order(:version, :rule_id)).
  CANONICAL_ORDER_COLUMNS = %i[version rule_id id].freeze

  # SQL ordering for query paths (lazy loads, pagination, non-serialized use).
  scope :canonical_order, -> { order(*CANONICAL_ORDER_COLUMNS) }

  # The LIVE requirement rows of the given component(s), regardless of STI
  # type — Rules for stig-kind, authored SrgRules for srg-kind. This is the
  # canonical scoping subquery for comment/triage/lock/release queries:
  # querying through the Rule STI association structurally excludes
  # authored SrgRules. BaseRule has no soft-delete default scope, so
  # deleted_at is excluded explicitly.
  scope :live_for_components, lambda { |component_ids|
    where(component_id: component_ids, deleted_at: nil)
  }

  # A plain dup carrying the four nested record collections — the shared
  # copy mechanic for authored-row generation and relocation moves.
  # Deliberately NOT amoeba: SrgRule's amoeba block retypes to Rule (the
  # import path), which is exactly wrong for same-type copies.
  def dup_with_nested_records
    copy = dup
    %i[rule_descriptions disa_rule_descriptions checks references].each do |assoc|
      copy.public_send(:"#{assoc}=", public_send(assoc).map(&:dup))
    end
    copy
  end

  # In-memory ordering for ALREADY-loaded collections (the serialization path).
  # Sorting the eager-loaded records in Ruby reorders them with zero extra
  # queries — calling the .canonical_order SQL scope on a loaded association
  # would instead re-query and drop the preload (an N+1). Produces the SAME
  # order as the SQL scope, including NULLs-last for a nil `version` (Postgres'
  # default for ORDER BY ASC), so the two primitives never disagree. `rule_id`
  # is NOT NULL and `id` is always unique, giving a deterministic total order.
  def self.canonical_sort(rules)
    rules.sort_by { |rule| [rule.version.nil? ? 1 : 0, rule.version.to_s, rule.rule_id.to_s, rule.id] }
  end

  # ONE numbering assignment for both requirement kinds: a blank-numbered
  # component row takes the next number from the component's kind-agnostic
  # sequence (largest_rule_id spans Rules and authored SrgRules and never
  # reissues tombstoned numbers). Catalog rows carry their own ids and no
  # component, so this never touches them.
  before_validation :set_rule_id
  before_create :ensure_disa_description_exists
  before_create :ensure_check_exists
  before_destroy :prevent_destroy_if_under_review_or_locked

  # Lock/review-state invariants shared across Rule and authored SrgRule —
  # locking behaves identically for both. Vacuous for catalog/StigRule
  # rows, which never carry locked/review state.
  validate :cannot_be_locked_and_under_review
  validate :locked_fields_must_be_valid_sections

  has_many :rule_descriptions, dependent: :destroy
  has_many :disa_rule_descriptions, dependent: :destroy
  has_many :checks, dependent: :destroy
  has_many :references, dependent: :destroy
  # Source-side relocation records cascade with a hard-destroyed source
  # row (open, declined, and executed alike) — declared HERE, not on
  # SrgRule,
  # because the component-destroy path traverses BaseRule-classed
  # all_requirement_rows and an SrgRule-only association would leave the
  # restrictive FK blocking that cascade. Vacuous for Rule/StigRule and
  # catalog rows, which never carry relocation records.
  has_many :requirement_relocations, foreign_key: :source_rule_id,
                                     inverse_of: :source_rule, dependent: :destroy
  # Target-side: destroying a landed requirement releases the link with
  # an audit note rather than blocking or silently nullifying — the
  # executed history row survives as the orphan the sweep finds. The
  # database-level nullify remains the backstop for bulk deletes.
  before_destroy :release_incoming_relocations
  # Reviews attach to any requirement row (Rule or authored SrgRule) via
  # the dual-written rule_id column — one shared review machinery.
  # inverse_of: false — Review#rule is Rule-classed (legacy back-compat)
  # and must not receive an SrgRule through inverse assignment.
  has_many :reviews, foreign_key: :rule_id, inverse_of: false, dependent: :destroy

  accepts_nested_attributes_for :rule_descriptions, :disa_rule_descriptions, :checks, :references, allow_destroy: true

  validates :status, inclusion: {
    in: STATUSES,
    message: "is not an acceptable value, acceptable values are: '#{STATUSES.compact_blank.join("', '")}'"
  }, if: :legacy_status_vocabulary?

  validates :rule_severity, inclusion: {
    in: SEVERITIES,
    message: "is not an acceptable value, acceptable values are: '#{SEVERITIES.compact_blank.join("', '")}'"
  }

  # Length limits — configurable via Settings.input_limits (env vars: VULCAN_LIMIT_*)
  validates :rule_id, :rule_weight, :version, :ident_system,
            :fixtext_fixref, :fix_id, :srg_id, :vuln_id, :legacy_ids,
            length: { maximum: ->(_r) { Settings.input_limits.short_string } }, allow_nil: true
  validates :ident,
            length: { maximum: ->(_r) { Settings.input_limits.ident } }, allow_nil: true
  validates :title,
            length: { maximum: ->(_r) { Settings.input_limits.title } }, allow_nil: true
  validates :status_justification,
            length: { maximum: ->(_r) { Settings.input_limits.medium_text } }, allow_nil: true
  validates :fixtext, :artifact_description, :vendor_comments,
            length: { maximum: ->(_r) { Settings.input_limits.long_text } }, allow_nil: true
  validates :inspec_control_body, :inspec_control_file,
            length: { maximum: ->(_r) { Settings.input_limits.inspec_code } }, allow_nil: true
  validates :inspec_control_body_lang, :inspec_control_file_lang,
            length: { maximum: ->(_r) { Settings.input_limits.short_string } }, allow_nil: true

  # In all cases of has_many, it is very unlikely (based on past releases of SRGs
  # that there will be multiple of these fields. Just take the first one.
  # Extend the model if required

  # Reject legacy idents for the same reason, array of idents not established
  def self.from_mapping(rule_class, rule_mapping)
    rule = rule_class.new(
      rule_id: rule_mapping.id,
      status: rule_mapping.status.first&.status || RuleConstants::STATUS_NYD,
      rule_severity: rule_mapping.severity || 'medium',
      rule_weight: rule_mapping.weight || '10.0',
      version: rule_mapping.version.first&.version,
      title: rule_mapping.title.first || nil,
      ident: rule_mapping.ident.reject(&:legacy).map(&:ident).sort.join(', '),
      legacy_ids: rule_mapping.ident.select(&:legacy).map(&:ident).join(', '),
      ident_system: rule_mapping.ident&.reject(&:legacy)&.first&.system,
      fixtext: rule_mapping.fixtext.first&.fixtext,
      fixtext_fixref: rule_mapping.fixtext.first&.fixref,
      fix_id: rule_mapping.fix.first&.id
    )

    rule.references.build(Reference.from_mapping(rule_mapping.reference.first))
    rule.disa_rule_descriptions.build(DisaRuleDescription.from_mapping(rule_mapping.description.first))
    rule.checks.build(Check.from_mapping(rule_mapping.check.first))
    rule
  end

  # Serialization is handled by RuleBlueprint / SrgRuleBlueprint / StigRuleBlueprint.
  # See app/blueprints/ for context-specific views (:navigator, :viewer, :editor).

  def nist_control_family
    ccis = ident.to_s.split(/, */)
    ia_controls = ccis.map { |cci| CCI_TO_NIST_CONSTANT[cci.to_sym] }
    ia_controls.uniq.join(', ')
  end

  # Returns the value for a given CSV column key
  # Used by Stig#csv_export and SecurityRequirementsGuide#csv_export
  def csv_value_for(column_key)
    case column_key
    when :rule_id then rule_id.to_s
    when :version then version.to_s
    when :srg_id then (respond_to?(:srg_id) ? srg_id : self[:srg_id]).to_s
    when :vuln_id then (respond_to?(:vuln_id) ? vuln_id : self[:vuln_id]).to_s
    when :rule_severity then rule_severity.to_s
    when :rule_weight then rule_weight.to_s
    when :title then title.to_s
    when :fixtext then fixtext.to_s
    when :ident then ident.to_s
    when :legacy_ids then legacy_ids.to_s
    when :status then status.to_s
    when :nist_control_family then nist_control_family
    when :vuln_discussion then disa_rule_descriptions.first&.vuln_discussion.to_s
    when :check_content then checks.first&.content.to_s
    when :mitigations then disa_rule_descriptions.first&.mitigations.to_s
    when :severity_override_guidance then disa_rule_descriptions.first&.severity_override_guidance.to_s
    when :false_positives then disa_rule_descriptions.first&.false_positives.to_s
    when :false_negatives then disa_rule_descriptions.first&.false_negatives.to_s
    else ''
    end
  end

  # The component-scoped display name (e.g. "SRGX-00-000001"). Meaningful
  # only for requirement rows (component-linked Rule / authored SrgRule).
  def displayed_name
    "#{component[:prefix]}-#{rule_id}"
  end

  private

  # System-side release of executed relocation links pointing at this
  # row as their landed target — audited, unlike the DB-level nullify.
  def release_incoming_relocations
    RequirementRelocation.executed.where(target_rule_id: id).find_each do |relocation|
      relocation.audit_comment = 'Relocation target destroyed — link released'
      relocation.update!(target_rule_id: nil)
    end
  end

  def cannot_be_locked_and_under_review
    return unless locked && review_requestor_id.present?

    errors.add(:base, 'Control cannot be under review and locked at the same time.')
  end

  def locked_fields_must_be_valid_sections
    return if locked_fields.blank?

    invalid = locked_fields.keys - LOCKABLE_SECTION_NAMES
    return if invalid.empty?

    errors.add(:locked_fields, "contains invalid section names: #{invalid.join(', ')}")
  end

  ##
  # Requirement rows are never deleted while under review or locked.
  # Checks *_was to cover the case where an attribute was changed before
  # attempting to destroy.
  def prevent_destroy_if_under_review_or_locked
    # Allow deletion if it is due to the parent being deleted
    return if destroyed_by_association.present?

    # Abort if under review and trying to delete
    if review_requestor_id_was.present?
      errors.add(:base, 'Control is under review and cannot be destroyed')
      throw(:abort)
    end

    # Abort if locked and trying to delete
    return unless locked_was

    errors.add(:base, 'Control is locked and cannot be destroyed')
    throw(:abort)
  end

  # Seam for per-profile status vocabularies: subclasses whose
  # rows are governed by an authoring profile (authored SrgRules) override
  # this to opt out of the legacy STIG-shaped inclusion and validate
  # against their profile's vocabulary instead. Rule and catalog rows keep
  # today's behavior.
  def legacy_status_vocabulary?
    true
  end

  def set_rule_id
    return if rule_id.present? || component_id.blank?

    self.rule_id = (component.largest_rule_id + 1).to_s.rjust(6, '0')
  end

  def ensure_disa_description_exists
    return unless disa_rule_descriptions.empty?

    disa_rule_descriptions << DisaRuleDescription.new(base_rule: self)
  end

  def ensure_check_exists
    return unless checks.empty?

    checks << Check.new(base_rule: self)
  end
end
