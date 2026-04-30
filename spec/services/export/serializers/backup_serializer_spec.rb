# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: BackupSerializer captures 100% of a component's data graph:
# component attributes, all rules with nested records, satisfactions as
# rule_id string pairs, reviews with user attribution, additional answers
# mapped by question name, and overlay parent references.
# ==========================================================================
TIMESTAMP_PATTERN = /\A\d{4}-\d{2}-\d{2}T/

RSpec.describe Export::Serializers::BackupSerializer do
  let_it_be(:project) { create(:project) }
  let_it_be(:component, refind: true) { create(:component, project: project) }
  let(:serializer) { described_class.new(component) }

  describe '#serialize' do
    subject(:data) { serializer.serialize }

    it 'returns a hash with component, rules, satisfactions, and reviews keys' do
      expect(data.keys).to contain_exactly(:component, :rules, :satisfactions, :reviews)
    end

    describe 'component serialization' do
      subject(:comp_data) { data[:component] }

      it 'includes all component attributes' do
        expect(comp_data[:name]).to eq(component.name)
        expect(comp_data[:prefix]).to eq(component.prefix)
        expect(comp_data[:version]).to eq(component.version)
        expect(comp_data[:release]).to eq(component.release)
        expect(comp_data[:title]).to eq(component.title)
        expect(comp_data[:description]).to eq(component.description)
        expect(comp_data[:released]).to eq(component.released)
        expect(comp_data[:admin_name]).to eq(component.admin_name)
        expect(comp_data[:admin_email]).to eq(component.admin_email)
        expect(comp_data[:advanced_fields]).to eq(component.advanced_fields)
      end

      it 'includes timestamps as ISO8601 strings' do
        expect(comp_data[:created_at]).to eq(component.created_at.iso8601)
        expect(comp_data[:updated_at]).to eq(component.updated_at.iso8601)
      end

      it 'includes based_on SRG reference' do
        expect(comp_data[:based_on][:srg_id]).to eq(component.based_on.srg_id)
        expect(comp_data[:based_on][:title]).to eq(component.based_on.title)
        expect(comp_data[:based_on][:version]).to eq(component.based_on.version)
      end

      it 'includes overlay_parent as nil when no parent' do
        expect(comp_data[:overlay_parent]).to be_nil
      end
    end

    describe 'rules serialization' do
      it 'includes all component rules' do
        expect(data[:rules].size).to eq(component.rules.size)
      end

      it 'preserves rule_id as the business key' do
        rule_ids = data[:rules].pluck(:rule_id)
        expected = component.rules.order(:rule_id).pluck(:rule_id)
        expect(rule_ids).to eq(expected)
      end

      it 'includes all base_rule columns except excluded ones' do
        rule_data = data[:rules].first
        expect(rule_data).to have_key(:status)
        expect(rule_data).to have_key(:rule_id)
        expect(rule_data).to have_key(:title)
        expect(rule_data).to have_key(:locked)
        expect(rule_data).to have_key(:rule_severity)
        expect(rule_data).to have_key(:fixtext)
        expect(rule_data).to have_key(:ident)
        expect(rule_data).to have_key(:vendor_comments)
        expect(rule_data).to have_key(:status_justification)
        expect(rule_data).to have_key(:artifact_description)
        expect(rule_data).to have_key(:inspec_control_body)
        expect(rule_data).to have_key(:inspec_control_file)
      end

      it 'excludes internal IDs from rule data' do
        rule_data = data[:rules].first
        excluded = Export::Serializers::BackupSerializer::EXCLUDED_RULE_COLUMNS
        excluded.each do |col|
          expect(rule_data).not_to have_key(col.to_sym), "Expected #{col} to be excluded"
        end
      end

      it 'includes srg_rule_version for re-linking on import' do
        rule = component.rules.first
        expected_version = rule.srg_rule&.version
        expect(data[:rules].first[:srg_rule_version]).to eq(expected_version)
      end

      it 'includes nested disa_rule_descriptions' do
        rule_data = data[:rules].first
        expect(rule_data[:disa_rule_descriptions]).to be_an(Array)
        # Each rule gets at least one disa_rule_description from base_rule callback
        expect(rule_data[:disa_rule_descriptions].first).to have_key('vuln_discussion')
      end

      it 'includes nested checks' do
        rule_data = data[:rules].first
        expect(rule_data[:checks]).to be_an(Array)
        expect(rule_data[:checks].first).to have_key('content')
      end

      it 'includes rule_descriptions array' do
        rule_data = data[:rules].first
        expect(rule_data[:rule_descriptions]).to be_an(Array)
      end

      it 'includes references array' do
        rule_data = data[:rules].first
        expect(rule_data[:references]).to be_an(Array)
      end

      it 'includes timestamps on each rule as ISO8601' do
        rule_data = data[:rules].first
        expect(rule_data[:created_at]).to match(TIMESTAMP_PATTERN)
        expect(rule_data[:updated_at]).to match(TIMESTAMP_PATTERN)
      end
    end

    describe 'satisfaction serialization' do
      let(:rules_ordered) { component.rules.order(:rule_id).to_a }

      before do
        # Rule 1 is "satisfied by" Rule 0 (i.e., Rule 0 fulfills Rule 1's requirement)
        # In rule_satisfactions table: rule_id = Rule 1, satisfied_by_rule_id = Rule 0
        RuleSatisfaction.create!(rule_id: rules_ordered[1].id, satisfied_by_rule_id: rules_ordered[0].id)
      end

      it 'serializes satisfactions as rule_id string pairs' do
        sats = data[:satisfactions]
        expect(sats.size).to eq(1)
        expect(sats.first).to have_key(:rule_id)
        expect(sats.first).to have_key(:satisfied_by_rule_id)
      end

      it 'uses rule_id strings (not DB IDs)' do
        sats = data[:satisfactions]
        # The serializer iterates rule.satisfies — which gives rules that this rule "satisfies"
        # rule_satisfactions: foreign_key = satisfied_by_rule_id, association_foreign_key = rule_id
        # So rules_ordered[0].satisfies = [rules_ordered[1]]
        sat_rule_ids = sats.pluck(:rule_id)
        sat_by_rule_ids = sats.pluck(:satisfied_by_rule_id)
        expect(sat_rule_ids + sat_by_rule_ids).to contain_exactly(
          rules_ordered[0].rule_id, rules_ordered[1].rule_id
        )
      end
    end

    describe 'review serialization' do
      let(:user) { create(:user) }

      before do
        rule = component.rules.first
        Review.create!(user: user, rule: rule, action: 'request_review', comment: 'Looks good')
      end

      it 'includes reviews with user attribution' do
        reviews = data[:reviews]
        expect(reviews.size).to eq(1)
        expect(reviews.first[:action]).to eq('request_review')
        expect(reviews.first[:comment]).to eq('Looks good')
        expect(reviews.first[:user_email]).to eq(user.email)
        expect(reviews.first[:user_name]).to eq(user.name)
      end

      it 'includes rule_id string for the review' do
        rule = component.rules.first
        expect(data[:reviews].first[:rule_id]).to eq(rule.rule_id)
      end

      it 'includes review timestamp as ISO8601' do
        expect(data[:reviews].first[:created_at]).to match(TIMESTAMP_PATTERN)
      end
    end

    # PR #717 — public-comment review workflow round-trip support. Backups
    # taken mid-review must preserve the full lifecycle so a restore reconstructs
    # disposition state without compliance loss. Validators on Review prevent
    # cross-component replies, so this section uses a single rule for all the
    # threaded examples.
    describe 'public-comment review lifecycle preservation' do
      let(:commenter) { create(:user, name: 'Commenter') }
      let(:triager) { create(:user, name: 'Triager') }
      let(:rule) { component.rules.first }

      before do
        # Reviews validate that the user has project access; seed memberships so
        # the per-test Review.create! calls pass the cross-scope validator.
        Membership.find_or_create_by!(user: commenter, membership: project) { |m| m.role = 'viewer' }
        Membership.find_or_create_by!(user: triager, membership: project) { |m| m.role = 'author' }
      end

      describe 'component fields' do # rubocop:disable RSpec/NestedGroups
        before do
          component.update!(
            comment_phase: 'open',
            comment_period_starts_at: '2026-04-15T00:00:00Z',
            comment_period_ends_at: '2026-04-30T00:00:00Z'
          )
          component.reload
        end

        it 'includes comment_phase' do
          expect(data[:component][:comment_phase]).to eq('open')
        end

        it 'includes comment_period_starts_at as ISO8601' do
          expect(data[:component][:comment_period_starts_at]).to match(TIMESTAMP_PATTERN)
        end

        it 'includes comment_period_ends_at as ISO8601' do
          expect(data[:component][:comment_period_ends_at]).to match(TIMESTAMP_PATTERN)
        end
      end

      describe 'review lifecycle fields' do # rubocop:disable RSpec/NestedGroups
        let!(:top_level) do
          Review.create!(user: commenter, rule: rule, action: 'comment',
                         comment: 'TLS 1.2 EOL concern',
                         section: 'check_content',
                         triage_status: 'concur_with_comment',
                         triage_set_by: triager, triage_set_at: 1.day.ago,
                         adjudicated_at: 12.hours.ago, adjudicated_by: triager)
        end
        let!(:reply) do
          Review.create!(user: triager, rule: rule, action: 'comment',
                         responding_to_review_id: top_level.id,
                         comment: 'will fix in next revision')
        end

        it 'preserves triage_status' do
          row = data[:reviews].find { |r| r[:comment] == 'TLS 1.2 EOL concern' }
          expect(row[:triage_status]).to eq('concur_with_comment')
        end

        it 'preserves section tag' do
          row = data[:reviews].find { |r| r[:comment] == 'TLS 1.2 EOL concern' }
          expect(row[:section]).to eq('check_content')
        end

        it 'preserves triage_set_by_email + triage_set_by_name + triage_set_at' do
          row = data[:reviews].find { |r| r[:comment] == 'TLS 1.2 EOL concern' }
          expect(row[:triage_set_by_email]).to eq(triager.email)
          expect(row[:triage_set_by_name]).to eq('Triager')
          expect(row[:triage_set_at]).to match(TIMESTAMP_PATTERN)
        end

        it 'preserves adjudicated_by_email + adjudicated_by_name + adjudicated_at' do
          row = data[:reviews].find { |r| r[:comment] == 'TLS 1.2 EOL concern' }
          expect(row[:adjudicated_by_email]).to eq(triager.email)
          expect(row[:adjudicated_by_name]).to eq('Triager')
          expect(row[:adjudicated_at]).to match(TIMESTAMP_PATTERN)
        end

        it 'tags each review with a stable external_id for re-linking' do
          ids = data[:reviews].pluck(:external_id)
          expect(ids.compact.uniq.size).to eq(data[:reviews].size)
        end

        it 'uses external_id to encode parent reference (responding_to_external_id)' do
          parent_row = data[:reviews].find { |r| r[:comment] == 'TLS 1.2 EOL concern' }
          reply_row  = data[:reviews].find { |r| r[:comment] == 'will fix in next revision' }
          expect(reply_row[:responding_to_external_id]).to eq(parent_row[:external_id])
        end
      end

      describe 'duplicate-of cross-link' do # rubocop:disable RSpec/NestedGroups
        let!(:original) do
          Review.create!(user: commenter, rule: rule, action: 'comment',
                         comment: 'duplicate target')
        end
        let!(:dup) do
          Review.create!(user: commenter, rule: rule, action: 'comment',
                         comment: 'duplicate source',
                         duplicate_of_review_id: original.id,
                         triage_status: 'duplicate')
        end

        it 'encodes duplicate_of as external_id' do
          original_row = data[:reviews].find { |r| r[:comment] == 'duplicate target' }
          dup_row      = data[:reviews].find { |r| r[:comment] == 'duplicate source' }
          expect(dup_row[:duplicate_of_external_id]).to eq(original_row[:external_id])
        end
      end
    end

    describe 'additional answers serialization' do
      before do
        question = component.additional_questions.create!(
          name: 'Test Question', question_type: 'freeform'
        )
        rule = component.rules.first
        AdditionalAnswer.create!(rule: rule, additional_question: question, answer: 'Test answer')
      end

      it 'maps answers by question name' do
        answers = data[:rules].first[:additional_answers]
        expect(answers.size).to eq(1)
        expect(answers.first[:question_name]).to eq('Test Question')
        expect(answers.first[:answer]).to eq('Test answer')
      end
    end
  end

  describe '#manifest_entry' do
    subject(:entry) { serializer.manifest_entry }

    it 'includes component identification fields' do
      expect(entry[:name]).to eq(component.name)
      expect(entry[:prefix]).to eq(component.prefix)
      expect(entry[:version]).to eq(component.version)
      expect(entry[:release]).to eq(component.release)
    end

    it 'includes SRG dependency info' do
      expect(entry[:srg_id]).to eq(component.based_on.srg_id)
      expect(entry[:srg_title]).to eq(component.based_on.title)
      expect(entry[:srg_version]).to eq(component.based_on.version)
    end

    it 'includes rule count' do
      expect(entry[:rule_count]).to eq(component.rules.size)
    end
  end
end
