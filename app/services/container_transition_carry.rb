# frozen_string_literal: true

# One-off Container SRG transition carry — a PURE CARRIER.
#
# Consumes the merged transition plan json as the instruction set (which
# comments, which APP-core target, which research note) and reads the
# actual Review rows live from the source component. Carries the team's
# comments onto the redo component's authored rows with original
# authorship on the imported-attribution columns, provenance on
# original_commentable_id, and threading intact (two-pass, the
# JSON-archive ReviewBuilder mechanics). Posts research context as
# clearly-labeled "[Transition research]" comments, never attributed as
# team comments.
#
# Writes NO requirement states: every target row remains Not Yet
# Determined — all state-setting happens in the authoring pass through
# the API. Carried comments restart their review cycle (top-level lands
# pending): the redo is a new component project; the old triage outcomes
# stay recorded on the source component and in the transition report.
class ContainerTransitionCarry
  class AlreadyCarried < StandardError; end

  RESEARCH_PREFIX = '[Transition research]'
  RESEARCH_AUTHOR = 'Transition research'

  Report = Struct.new(:carried, :research_noted, :skipped, keyword_init: true)

  def initialize(plan_path:, target_component:)
    @plan_path = plan_path
    @target = target_component
  end

  def call
    raise ArgumentError, "target must be an srg-kind component (got #{@target.document_type})" unless
      @target.document_type == 'srg'

    refuse_if_already_carried!

    report = Report.new(carried: [], research_noted: [], skipped: [])
    ActiveRecord::Base.transaction do
      plan_rows.each { |row| carry_row(row, report) }
    end
    report
  end

  private

  def plan_rows
    JSON.parse(File.read(@plan_path)).fetch('rows')
  end

  # Provenance markers are the idempotence guard: a target already holding
  # carried comments (original_commentable_id) or research notes means the
  # carry ran — refuse rather than double-write.
  def refuse_if_already_carried!
    scope = Review.where(rule_id: @target.requirements.select(:id))
    return unless scope.where.not(original_commentable_id: nil)
                       .or(scope.where('comment LIKE ?', "#{RESEARCH_PREFIX}%")).exists?

    raise AlreadyCarried, "component #{@target.id} already holds carried comments or research notes"
  end

  def target_rows_by_version
    @target_rows_by_version ||= @target.authored_srg_rules.includes(:derived_from)
                                       .index_by { |r| r.derived_from&.version }
  end

  def carry_row(row, report)
    displayed = row.dig('source', 'displayed')
    version = row.dig('target', 'app_core_requirement')
    if version.nil?
      report.skipped << { displayed: displayed, target: nil, reason: row['skip_reason'] || 'no APP-core target' }
      return
    end

    target_row = target_rows_by_version[version]
    if target_row.nil?
      report.skipped << { displayed: displayed, target: version,
                          reason: "target row #{version} not found on the component" }
      return
    end

    carried_count = carry_comments(row.fetch('carry_comment_ids'), target_row)
    report.carried << { displayed: displayed, target: version, comments: carried_count } if carried_count.positive?
    return if row['research_note'].blank?

    post_research_note(row['research_note'], target_row)
    report.research_noted << { displayed: displayed, target: version }
  end

  # Two-pass thread carry: planned top-level comments first (id map), then
  # every reply of a carried parent, remapped. Replies ride with their
  # thread regardless of plan listing — the thread is the carry unit; the
  # noise ruling applies to top-level selection. The same-rule reply
  # validator holds because parent and child land on the same target row.
  def carry_comments(comment_ids, target_row)
    return 0 if comment_ids.empty?

    parents = Review.where(id: comment_ids).order(:created_at)
    id_map = parents.index_with { |src| insert_carried(src, target_row, responding_to: nil) }

    replies = Review.where(responding_to_review_id: id_map.keys.map(&:id)).order(:created_at)
    replies.each do |src|
      new_parent_id = id_map[id_map.keys.find { |p| p.id == src.responding_to_review_id }]
      insert_carried(src, target_row, responding_to: new_parent_id)
    end

    id_map.size + replies.size
  end

  def insert_carried(src, target_row, responding_to:)
    attrs = {
      rule_id: target_row.id,
      # Dual-write the polymorphic target: insert! skips
      # sync_commentable_from_rule (ReviewBuilder precedent).
      commentable_type: 'BaseRule',
      commentable_id: target_row.id,
      action: 'comment',
      comment: src.comment,
      section: src.section,
      user_id: nil,
      commenter_imported_name: src.user&.name || src.commenter_imported_name,
      commenter_imported_email: src.user&.email || src.commenter_imported_email,
      original_commentable_id: src.rule_id,
      responding_to_review_id: responding_to,
      # Fresh review cycle on the new component: top-level lands pending,
      # replies stay untriaged (the model's own rule).
      triage_status: responding_to.nil? ? 'pending' : nil,
      created_at: src.created_at,
      updated_at: src.updated_at
    }
    insert_and_verify(attrs)
  end

  def post_research_note(note, target_row)
    now = Time.zone.now
    insert_and_verify(
      rule_id: target_row.id,
      commentable_type: 'BaseRule',
      commentable_id: target_row.id,
      action: 'comment',
      comment: "#{RESEARCH_PREFIX} #{note}",
      section: nil,
      user_id: nil,
      commenter_imported_name: RESEARCH_AUTHOR,
      commenter_imported_email: nil,
      original_commentable_id: nil,
      triage_status: 'pending',
      created_at: now,
      updated_at: now
    )
  end

  # rubocop:disable Rails/SkipsModelValidations
  # Direct INSERT bypasses model callbacks (the ReviewBuilder /
  # duplicate_reviews_and_history precedent): carried historical comments
  # must not re-fire create-time gates (membership checks, phase gates,
  # satisfied-by redirects). The import-integrity validity pass below is
  # the guard that replaces them.
  def insert_and_verify(attrs)
    id = Review.insert!(attrs).rows.first.first
    record = Review.find(id)
    raise ActiveRecord::RecordInvalid, record unless record.valid?(:import_integrity)

    id
  end
  # rubocop:enable Rails/SkipsModelValidations
end
