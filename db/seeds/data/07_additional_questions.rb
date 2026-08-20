# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding additional questions and answers...'

container_platform = Project.find_by(name: 'Container Platform')
container_component = container_platform&.components&.find_by(name: 'Container Platform')

if container_component.nil?
  puts '  No Container Platform component — skipping additional questions'
  return
end

# ── Additional Questions (component-level custom fields) ──

q_tech_area = AdditionalQuestion.find_or_create_by!(
  component: container_component,
  name: 'Technology Area'
) do |q|
  q.question_type = 'freeform'
end

q_deploy_scope = AdditionalQuestion.find_or_create_by!(
  component: container_component,
  name: 'Deployment Scope'
) do |q|
  q.question_type = 'freeform'
end

puts "  #{AdditionalQuestion.where(component: container_component).count} additional questions on Container Platform"

# ── Additional Answers (per-rule answers to the questions above) ──

rules = container_component.rules.order(:rule_id).limit(3).to_a

answer_data = [
  { rule: rules[0], question: q_tech_area, answer: 'Container Runtime' },
  { rule: rules[0], question: q_deploy_scope, answer: 'All environments' },
  { rule: rules[1], question: q_tech_area, answer: 'Network Security' },
  { rule: rules[1], question: q_deploy_scope, answer: 'Production only' },
  { rule: rules[2], question: q_tech_area, answer: 'Identity and Access Management' },
  { rule: rules[2], question: q_deploy_scope, answer: 'All environments' }
]

answer_data.each do |entry|
  next unless entry[:rule]

  AdditionalAnswer.find_or_create_by!(
    rule: entry[:rule],
    additional_question: entry[:question]
  ) do |a|
    a.answer = entry[:answer]
  end
end

puts "  #{AdditionalAnswer.where(additional_question: [q_tech_area, q_deploy_scope]).count} additional answers seeded"
# rubocop:enable Rails/Output
