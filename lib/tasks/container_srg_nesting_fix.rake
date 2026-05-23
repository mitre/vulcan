# frozen_string_literal: true

namespace :container_srg do
  desc 'Fix ~25 miscategorized satisfaction rows in Container SRG (dry-run by default)'
  task fix_nesting: :environment do
    component = Component.find_by!(prefix: 'CNTR-00')
    dry_run = ENV.fetch('EXECUTE', 'false') != 'true'

    puts dry_run ? '=== DRY RUN (set EXECUTE=true to apply) ===' : '=== EXECUTING ==='
    puts "Component: #{component.id} - #{component.prefix} - #{component.name}"
    puts

    moves = build_move_list
    dedup = build_dedup_list(component)

    puts "--- Moves (#{moves.size}) ---"
    moves.each do |m|
      label = "#{component.prefix}-#{m[:child_rule_id]}"
      from = "#{component.prefix}-#{m[:from_parent]}"
      to = "#{component.prefix}-#{m[:to_parent]}"
      puts "  #{label.ljust(16)} #{from} → #{to}  (#{m[:reason]})"
    end

    puts
    puts "--- Dedup 000050/000051 (#{dedup.size} rows to remove from 000051) ---"
    dedup.each do |d|
      puts "  Remove: #{component.prefix}-#{d[:child_rule_id]} from 000051"
    end

    unless dry_run
      puts
      apply_moves(component, moves)
      apply_dedup(component, dedup)
      reapply_adnm(component, moves)
      puts
      puts '=== COMPLETE ==='
      print_summary(component)
    end
  end
end

def build_move_list
  moves = []

  auth_to_no_login = %w[001228 001302 001373 001383 001384 001385 001386 001387 001388 001403 001745]
  moves += auth_to_no_login.map { |rid| { child_rule_id: rid, from_parent: '000010', to_parent: '000030', reason: 'auth → no login' } }

  accounts_to_no_login = %w[001002 001003 001024]
  moves += accounts_to_no_login.map { |rid| { child_rule_id: rid, from_parent: '000020', to_parent: '000030', reason: 'account lifecycle → no login' } }

  hardware_to_platform = %w[001175 001299 001300 001378 001397 001417]
  moves += hardware_to_platform.map { |rid| { child_rule_id: rid, from_parent: '000020', to_parent: '000010', reason: 'hardware/wireless → platform' } }

  moves << { child_rule_id: '001203', from_parent: '000030', to_parent: '000120', reason: 'input validation → application STIG' }

  security_attrs_to_info_flow = %w[001177 001178]
  moves += security_attrs_to_info_flow.map { |rid| { child_rule_id: rid, from_parent: '000060', to_parent: '000090', reason: 'security attributes → info flow' } }

  moves
end

def build_dedup_list(component)
  keep_parent = component.rules.find_by!(rule_id: '000050')
  remove_parent = component.rules.find_by!(rule_id: '000051')
  shared_ids = keep_parent.satisfies.pluck(:rule_id) & remove_parent.satisfies.pluck(:rule_id)
  shared_ids.map { |rid| { child_rule_id: rid, remove_from_parent: '000051' } }
end

def apply_moves(component, moves)
  conn = ActiveRecord::Base.connection
  moves.each do |m|
    child = component.rules.find_by(rule_id: m[:child_rule_id])
    from_parent = component.rules.find_by(rule_id: m[:from_parent])
    to_parent = component.rules.find_by(rule_id: m[:to_parent])

    unless child && from_parent && to_parent
      puts "  SKIP: #{m[:child_rule_id]} — rule not found"
      next
    end

    deleted = conn.delete(
      sanitize_satisfaction_sql('DELETE FROM rule_satisfactions WHERE rule_id = ? AND satisfied_by_rule_id = ?',
                                child.id, from_parent.id)
    )
    unless deleted.positive?
      puts "  SKIP: #{m[:child_rule_id]} — not currently under #{m[:from_parent]}"
      next
    end

    conn.execute(
      sanitize_satisfaction_sql('INSERT INTO rule_satisfactions (rule_id, satisfied_by_rule_id) VALUES (?, ?)',
                                child.id, to_parent.id)
    )
    puts "  MOVED: #{component.prefix}-#{m[:child_rule_id]}  #{m[:from_parent]} → #{m[:to_parent]}"
  end
end

def apply_dedup(component, dedup)
  conn = ActiveRecord::Base.connection
  remove_parent = component.rules.find_by!(rule_id: '000051')
  dedup.each do |d|
    child = component.rules.find_by(rule_id: d[:child_rule_id])
    next unless child

    deleted = conn.delete(
      sanitize_satisfaction_sql('DELETE FROM rule_satisfactions WHERE rule_id = ? AND satisfied_by_rule_id = ?',
                                child.id, remove_parent.id)
    )
    puts "  DEDUP: removed #{d[:child_rule_id]} from 000051" if deleted.positive?
  end
end

def reapply_adnm(component, moves)
  puts
  puts '--- Re-applying ADNM status on moved children ---'
  moves.each do |m|
    child = component.rules.find_by(rule_id: m[:child_rule_id])
    to_parent = component.rules.find_by(rule_id: m[:to_parent])
    next unless child && to_parent

    child.apply_nesting_status!(to_parent)
    puts "  ADNM: #{component.prefix}-#{m[:child_rule_id]} → mitigation references #{m[:to_parent]}"
  end
end

def print_summary(component)
  puts '--- Post-fix summary ---'
  component.rules.includes(:satisfies).select { |r| r.satisfies.any? }.sort_by(&:rule_id).each do |r|
    puts "  #{component.prefix}-#{r.rule_id.ljust(8)} #{r.satisfies.count.to_s.rjust(3)} children"
  end
  total = RuleSatisfaction.where(rule_id: component.rules.ids)
                          .or(RuleSatisfaction.where(satisfied_by_rule_id: component.rules.ids))
                          .count
  puts "  Total satisfactions: #{total}"
end

def sanitize_satisfaction_sql(template, *values)
  ActiveRecord::Base.sanitize_sql_array([template, *values])
end

namespace :container_srg do
  desc 'Backfill ADNM status on children + auto-adjudicate pending comments as addressed_by (dry-run by default)'
  task backfill_adnm: :environment do
    component_id = ENV.fetch('COMPONENT_ID', '29')
    component = Component.find(component_id)
    dry_run = ENV.fetch('EXECUTE', 'false') != 'true'
    admin = User.find_by(admin: true)

    puts dry_run ? '=== DRY RUN (set EXECUTE=true to apply) ===' : '=== EXECUTING ==='
    puts "Component: #{component.id} - #{component.prefix} - #{component.name}"
    puts

    children = component.rules.includes(:satisfied_by, :disa_rule_descriptions).select { |r| r.satisfied_by.any? }
    wrong_status = children.reject { |r| r.status == 'Applicable - Does Not Meet' }
    child_ids = children.map(&:id)
    pending_comments = Review.where(rule_id: child_ids, action: 'comment',
                                    responding_to_review_id: nil, triage_status: 'pending')

    puts "Children with satisfied_by: #{children.size}"
    puts "  Already ADNM: #{children.size - wrong_status.size}"
    puts "  Need ADNM fix: #{wrong_status.size}"
    puts "Pending comments on children: #{pending_comments.count}"
    puts

    puts '--- ADNM status fixes ---'
    wrong_status.each do |child|
      parent = child.satisfied_by.first
      puts "  #{component.prefix}-#{child.rule_id.ljust(8)} #{child.status} → ADNM (parent: #{parent.rule_id})"
      child.apply_nesting_status!(parent) unless dry_run
    end

    puts
    puts '--- Comment adjudication ---'
    pending_comments.find_each do |comment|
      parent = children.find { |r| r.id == comment.rule_id }&.satisfied_by&.first
      unless parent
        puts "  SKIP ##{comment.id}: no parent found for rule_id #{comment.rule_id}"
        next
      end

      puts "  ##{comment.id} on #{component.prefix}-#{comment.rule&.rule_id} → addressed_by #{parent.rule_id}"
      next if dry_run

      Review.transaction do
        comment.update!(
          triage_status: 'addressed_by',
          addressed_by_rule_id: parent.id,
          triage_set_by_id: admin.id,
          triage_set_at: Time.current,
          audit_comment: "Auto-adjudicated: requirement addressed by #{component.prefix}-#{parent.rule_id}"
        )

        Review.create!(
          action: 'comment',
          comment: "This requirement is addressed by #{component.prefix}-#{parent.rule_id}. " \
                   'Your feedback applies to that requirement.',
          user: admin,
          rule: comment.rule,
          responding_to_review_id: comment.id,
          section: comment.section
        )
      end
    end

    puts
    puts '=== SUMMARY ==='
    if dry_run
      puts "Would fix #{wrong_status.size} rules + adjudicate #{pending_comments.count} comments"
      puts 'Re-run with EXECUTE=true to apply'
    else
      remaining = component.rules.includes(:satisfied_by)
                           .select { |r| r.satisfied_by.any? && r.status != 'Applicable - Does Not Meet' }
      puts "Rules still needing ADNM: #{remaining.size}"
      still_pending = Review.where(rule_id: child_ids, action: 'comment',
                                   responding_to_review_id: nil, triage_status: 'pending')
      puts "Comments still pending: #{still_pending.count}"
    end
  end
end
