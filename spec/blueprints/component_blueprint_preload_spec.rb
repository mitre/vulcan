# frozen_string_literal: true

require 'rails_helper'

# The requirement worth guarding here is not what the payload contains — it is how
# many times the database is asked for it. Serializing a component walks every
# requirement and every requirement's checks, descriptions, reviews and audit
# trail; if those are fetched per row the page cost grows with the size of the
# component, and the output looks exactly the same either way. So each example
# renders the SAME view over two components differing only in how many
# requirements they hold, and asserts which loads move.
#
# A load that scales with requirement count is the defect, and no view is allowed
# one. The audit trail used to be the exception — it cannot be preloaded, being a
# union built per record rather than an association — so it is no longer sent for
# a whole collection at all; the per-requirement endpoint serves it for the one
# requirement whose history is displayed.
#
# A requirement also carries comments and satisfaction links, and serializing
# those reaches further still — to comment authors, and to the source requirement
# behind each linked row. Each is its own axis, and each has its own example
# below that holds everything else equal and varies only that one.
RSpec.describe 'Component requirement serialization preloading' do
  # Far enough apart that a single lazy association is unmissable: nine extra
  # requirements means at least nine extra queries. Methods rather than constants
  # because a constant written inside this block would be defined on Object.
  def few_requirements
    3
  end

  def many_requirements
    12
  end

  # Query sources that issue MORE calls for more requirements — i.e. per-row work.
  def scaling_loads(small, large)
    large.by_name.filter_map { |name, count| name if count > small.by_name.fetch(name, 0) }
  end

  def reports_for(small_component, large_component, view)
    [count_queries { ComponentBlueprint.render(small_component, view: view) },
     count_queries { ComponentBlueprint.render(large_component, view: view) }]
  end

  shared_examples 'a collection serialized without per-requirement queries' do
    it 'issues the same total number of queries regardless of requirement count' do
      small, large = reports_for(small_component, large_component, :show)

      expect(large.total).to eq(small.total),
                             "show view scaled with requirement count.\n" \
                             "with #{few_requirements}:\n#{small}\n\n" \
                             "with #{many_requirements}:\n#{large}"
    end

    it 'issues the same number of queries in the editor view too' do
      small, large = reports_for(small_component, large_component, :editor)

      expect(scaling_loads(small, large)).to be_empty,
                                             "editor view scaled with requirement count.\n" \
                                             "with #{few_requirements}:\n#{small}\n\n" \
                                             "with #{many_requirements}:\n#{large}"
    end
  end

  context 'with a stig-kind component' do
    # Each requirement gets its OWN source requirement. The factory otherwise
    # reuses one shared catalog row for every rule, which hides anything reached
    # THROUGH that row: the count would not move no matter how many requirements
    # exist, because they all point at the same record.
    def stig_component_with(count)
      create(:component, :skip_rules).tap do |c|
        count.times do
          create(:rule, component: c,
                        srg_rule: create(:srg_rule,
                                         security_requirements_guide_id: c.security_requirements_guide_id))
        end
      end
    end

    let_it_be(:small_component) { stig_component_with(few_requirements) }
    let_it_be(:large_component) { stig_component_with(many_requirements) }

    it_behaves_like 'a collection serialized without per-requirement queries'
  end

  context 'with an srg-kind component' do
    let_it_be(:small_component) do
      create(:component, :skip_rules, document_type: 'srg').tap do |c|
        create_list(:srg_rule, few_requirements, :authored, component: c)
      end
    end
    let_it_be(:large_component) do
      create(:component, :skip_rules, document_type: 'srg').tap do |c|
        create_list(:srg_rule, many_requirements, :authored, component: c)
      end
    end

    it_behaves_like 'a collection serialized without per-requirement queries'
  end

  # A requirement's comments are the other axis that grows. Serializing a review
  # asks for its reply count and its author, so a requirement carrying ten
  # comments costs several times one carrying two — while the requirement count
  # stays flat. This holds requirements equal and varies only the comments.
  describe 'with comments on a requirement' do
    def component_with_comments(count)
      create(:component, :skip_rules).tap do |component|
        rule = create(:rule, component: component)
        create_list(:review, count, :comment, rule: rule, user: create(:user))
      end
    end

    let_it_be(:few_comments) { component_with_comments(2) }
    let_it_be(:many_comments) { component_with_comments(10) }

    it 'renders the editor view with a query count independent of comment count' do
      small = count_queries { ComponentBlueprint.render(few_comments, view: :editor) }
      large = count_queries { ComponentBlueprint.render(many_comments, view: :editor) }

      expect(large.total).to eq(small.total),
                             "editor view scaled with comment count.\n" \
                             "with 2 comments:\n#{small}\n\nwith 10 comments:\n#{large}"
    end
  end

  # The third axis. A satisfaction link renders through its own blueprint, which
  # asks the linked requirement for its SRG identifier and its owning component's
  # prefix. Requirement count is held equal here; only the number of links moves.
  describe 'with satisfaction links between requirements' do
    def component_with_links(count)
      create(:component, :skip_rules).tap do |component|
        parent = create(:rule, component: component)
        count.times do
          child = create(:rule, component: component,
                                srg_rule: create(:srg_rule,
                                                 security_requirements_guide_id:
                                                   component.security_requirements_guide_id))
          child.satisfied_by << parent
        end
      end
    end

    let_it_be(:few_links) { component_with_links(2) }
    let_it_be(:many_links) { component_with_links(8) }

    it 'renders the editor view with a query count independent of link count' do
      small = count_queries { ComponentBlueprint.render(few_links, view: :editor) }
      large = count_queries { ComponentBlueprint.render(many_links, view: :editor) }

      moved = large.by_name.select { |name, count| count > small.by_name.fetch(name, 0) }

      expect(moved).to be_empty,
                       "editor view scaled with satisfaction-link count.\n" \
                       "with 2 links:\n#{small}\n\nwith 8 links:\n#{large}"
    end
  end

  # The extension builds its plan by matching declared association names against
  # the model's own reflections. The requirement blueprints deliberately name
  # several associations `*_attributes` to match the payload contract, and those
  # names match no reflection — so they contribute nothing unless annotated. These
  # examples assert the plan actually covers each dependency, because a silently
  # empty plan is exactly how this defect went unnoticed.
  describe 'the preload plan derived from each requirement blueprint' do
    def plan_for(blueprint, view, model)
      BlueprinterActiveRecord::Preloader.preloads(blueprint, view, model: model)
    end

    it 'covers every association RuleBlueprint reads in the viewer view' do
      expect(plan_for(RuleBlueprint, :viewer, Rule).keys)
        .to include(:reviews, :srg_rule, :disa_rule_descriptions, :checks, :satisfies, :satisfied_by)
    end

    it 'covers every association RuleBlueprint reads in the editor view' do
      expect(plan_for(RuleBlueprint, :editor, Rule).keys)
        .to include(:reviews, :srg_rule, :disa_rule_descriptions, :checks,
                    :rule_descriptions, :additional_answers, :satisfies, :satisfied_by)
    end

    # The source requirement is rendered by its own blueprint through a plain
    # field, which the extension cannot follow — so what gets read FROM it has
    # to be declared here. Asserting only the top-level :srg_rule key would
    # pass even with this nested plan deleted, because other fields contribute
    # that key on their own.
    it 'reaches through the source requirement to the content rendered from it' do
      expect(plan_for(RuleBlueprint, :editor, Rule)[:srg_rule])
        .to include(:checks, :disa_rule_descriptions, :rule_descriptions, :security_requirements_guide)
    end

    it 'covers the owning component behind a picker row displayed name' do
      expect(plan_for(RuleBlueprint, :picker, Rule).keys).to include(:component, :satisfies, :satisfied_by)
    end

    # :derived_from is here because a field never resolves by name — only a
    # declared association does. It reads like it would be found automatically,
    # which is exactly why leaving it unasserted would let its annotation be
    # dropped without a single test noticing.
    it 'covers every association AuthoredSrgRuleBlueprint reads in the viewer view' do
      expect(plan_for(AuthoredSrgRuleBlueprint, :viewer, SrgRule).keys)
        .to include(:reviews, :disa_rule_descriptions, :checks, :rule_descriptions, :derived_from)
    end

    it 'covers every association AuthoredSrgRuleBlueprint reads in the editor view' do
      expect(plan_for(AuthoredSrgRuleBlueprint, :editor, SrgRule).keys)
        .to include(:reviews, :disa_rule_descriptions, :checks, :rule_descriptions, :derived_from)
    end
  end
end
