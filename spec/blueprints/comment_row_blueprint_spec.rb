# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommentRowBlueprint do
  let(:project) { create(:project) }
  let(:component) { create(:component, project: project) }
  let(:rule) { component.rules.first || create(:rule, component: component) }
  let(:user) { create(:user) }

  let(:review) do
    create(:review, :comment, user: user, commentable: rule, rule_id: rule.id,
                              section: 'check_content', triage_status: 'pending')
  end

  let(:options) do
    {
      responses_counts: { review.id => 2 },
      reaction_counts: { [review.id, 'up'] => 3, [review.id, 'down'] => 1 },
      rule_display_map: { rule.id => "#{component.prefix}-#{rule.rule_id}" }
    }
  end

  describe 'default view' do
    subject(:result) { described_class.render_as_json(review, **options) }

    it 'includes shared base fields' do
      expect(result).to include(
        'id' => review.id,
        'comment' => review.comment,
        'triage_status' => 'pending',
        'section' => 'check_content',
        'commentable_type' => 'BaseRule'
      )
      expect(result).to have_key('created_at')
    end

    it 'includes computed responses_count from options' do
      expect(result['responses_count']).to eq(2)
    end

    it 'includes computed reactions from options' do
      expect(result['reactions']).to eq({ 'up' => 3, 'down' => 1 })
    end

    it 'includes rule_displayed_name from options map' do
      expect(result['rule_displayed_name']).to eq("#{component.prefix}-#{rule.rule_id}")
    end

    it 'does NOT include view-specific fields' do
      expect(result).not_to have_key('component_name')
      expect(result).not_to have_key('project_name')
      expect(result).not_to have_key('latest_activity_at')
    end
  end

  describe ':component view' do
    subject(:result) { described_class.render_as_json(review, view: :component, **options) }

    it 'includes attribution fields' do
      expect(result).to have_key('triager_display_name')
      expect(result).to have_key('commenter_display_name')
      expect(result).to have_key('adjudicator_display_name')
    end

    it 'includes component-specific fields' do
      expect(result).to have_key('author_email')
      expect(result).to have_key('updated_at')
      expect(result).to have_key('rule_status')
    end
  end

  describe ':project view' do
    subject(:result) { described_class.render_as_json(review, view: :project, **options) }

    it 'includes component_id and component_name' do
      expect(result).to have_key('component_id')
      expect(result).to have_key('component_name')
    end

    it 'includes attribution fields' do
      expect(result).to have_key('triager_display_name')
      expect(result).to have_key('adjudicator_display_name')
    end

    it 'does NOT include component-only fields' do
      expect(result).not_to have_key('author_email')
      expect(result).not_to have_key('rule_status')
    end
  end

  describe ':user view' do
    subject(:result) { described_class.render_as_json(review, view: :user, **options) }

    it 'includes project and component identifiers' do
      expect(result).to have_key('project_id')
      expect(result).to have_key('project_name')
      expect(result).to have_key('component_id')
      expect(result).to have_key('component_name')
    end

    it 'includes latest_activity_at' do
      expect(result).to have_key('latest_activity_at')
    end
  end
end
