# frozen_string_literal: true

# Collapse comment_phase from a four-value enum
# (draft / open / adjudication / final) to a two-value model
# (open / closed) with an optional `closed_reason`
# (adjudicating / finalized) decorating the closed state.
#
# Data migration:
#   draft        → open
#   open         → open   (no-op)
#   adjudication → closed + closed_reason: 'adjudicating'
#   final        → closed + closed_reason: 'finalized'
#
# The down direction is lossy: a closed-without-reason row collapses
# to 'draft' on rollback because the legacy enum had no equivalent.
class NormalizeCommentPhaseToOpenClosed < ActiveRecord::Migration[8.0]
  def up
    add_column :components, :closed_reason, :string
    add_index  :components, :closed_reason

    # Raw SQL — applying the application Component model's validators
    # here would reject the legacy values mid-migration.
    execute(<<~SQL.squish)
      UPDATE components
      SET    comment_phase = 'open'
      WHERE  comment_phase = 'draft'
    SQL

    execute(<<~SQL.squish)
      UPDATE components
      SET    comment_phase = 'closed',
             closed_reason = 'adjudicating'
      WHERE  comment_phase = 'adjudication'
    SQL

    execute(<<~SQL.squish)
      UPDATE components
      SET    comment_phase = 'closed',
             closed_reason = 'finalized'
      WHERE  comment_phase = 'final'
    SQL

    change_column_default :components, :comment_phase, from: 'draft', to: 'open'
  end

  def down
    execute(<<~SQL.squish)
      UPDATE components
      SET    comment_phase = 'adjudication',
             closed_reason = NULL
      WHERE  comment_phase = 'closed'
        AND  closed_reason = 'adjudicating'
    SQL

    execute(<<~SQL.squish)
      UPDATE components
      SET    comment_phase = 'final',
             closed_reason = NULL
      WHERE  comment_phase = 'closed'
        AND  closed_reason = 'finalized'
    SQL

    execute(<<~SQL.squish)
      UPDATE components
      SET    comment_phase = 'draft'
      WHERE  comment_phase = 'closed'
        AND  closed_reason IS NULL
    SQL

    change_column_default :components, :comment_phase, from: 'open', to: 'draft'
    remove_index  :components, :closed_reason
    remove_column :components, :closed_reason
  end
end
