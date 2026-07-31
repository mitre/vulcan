# frozen_string_literal: true

# One-off Container SRG transition carry (pure carrier — writes no
# requirement states). See ContainerTransitionCarry.
#
#   bin/rails "container_transition:carry[<plan_path>,<target_component_id>]"
namespace :container_transition do
  desc 'Carry Container review context onto the APP-core redo component per the merged plan json'
  task :carry, %i[plan_path target_component_id] => :environment do |_t, args|
    plan_path = args.fetch(:plan_path)
    target = Component.find(args.fetch(:target_component_id))

    report = ContainerTransitionCarry.new(plan_path: plan_path, target_component: target).call

    puts "carried:        #{report.carried.size} rows / #{report.carried.sum { |r| r[:comments] }} comments"
    report.carried.each { |r| puts "  #{r[:displayed]} -> #{r[:target]}: #{r[:comments]} comments" }
    puts "research notes: #{report.research_noted.size}"
    report.research_noted.each { |r| puts "  #{r[:displayed]} -> #{r[:target]}" }
    puts "skipped:        #{report.skipped.size}"
    report.skipped.each do |r|
      label = [r[:displayed], r[:target]].compact.join(' -> ')
      puts "  #{label} — #{r[:reason]}"
    end
  end
end
