# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Triage badge standardization' do
  describe 'TriageStatusBadge consumers pass addressed_by props' do
    let(:vue_dir) { Rails.root.join('app/javascript/components') }

    let(:badge_consumers) do
      Dir.glob(vue_dir.join('**/*.vue')).select do |path|
        content = File.read(path)
        content.include?('<TriageStatusBadge') && !path.end_with?('TriageStatusBadge.vue')
      end
    end

    it 'every consumer passes :addressed-by-rule-id prop' do
      missing = badge_consumers.reject { |f| File.read(f).include?(':addressed-by-rule-id') }
      expect(missing).to be_empty,
                         "These files use TriageStatusBadge without :addressed-by-rule-id:\n" \
                         "#{missing.map { |f| f.sub("#{vue_dir}/", '') }.join("\n")}"
    end

    it 'every consumer passes :addressed-by-rule-name prop' do
      missing = badge_consumers.reject { |f| File.read(f).include?(':addressed-by-rule-name') }
      expect(missing).to be_empty,
                         "These files use TriageStatusBadge without :addressed-by-rule-name:\n" \
                         "#{missing.map { |f| f.sub("#{vue_dir}/", '') }.join("\n")}"
    end
  end

  describe 'User comments row includes addressed_by fields' do
    let(:controller_source) { Rails.root.join('app/controllers/users_controller.rb').read }

    it 'comment_row_for includes addressed_by_rule_id' do
      expect(controller_source).to include('addressed_by_rule_id'),
                                   'users_controller comment_row_for missing addressed_by_rule_id'
    end

    it 'comment_row_for includes duplicate_of_review_id' do
      expect(controller_source).to include('duplicate_of_review_id'),
                                   'users_controller comment_row_for missing duplicate_of_review_id'
    end
  end
end
