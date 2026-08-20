# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Review, '#original_commentable_id' do
  let_it_be(:project) { create(:project) }
  let_it_be(:component) do
    create(:component, project: project,
                       comment_phase: 'open',
                       comment_period_starts_at: 1.day.ago,
                       comment_period_ends_at: 1.day.from_now)
  end
  let_it_be(:user) do
    u = create(:user)
    Membership.find_or_create_by!(user: u, membership: project) { |m| m.role = 'viewer' }
    u
  end
  let_it_be(:rule_a) { component.rules.first }
  let_it_be(:rule_b) { component.rules.second }

  describe 'column existence' do
    it 'has original_commentable_id column' do
      expect(Review.column_names).to include('original_commentable_id')
    end

    it 'defaults to NULL for new comments' do
      review = Review.create!(
        rule: rule_a,
        commentable: rule_a,
        user: user,
        action: 'comment',
        comment: 'Direct comment on parent'
      )
      expect(review.original_commentable_id).to be_nil
    end

    it 'can be set to a rule DB id' do
      review = Review.create!(
        rule: rule_a,
        commentable: rule_a,
        user: user,
        action: 'comment',
        comment: 'Moved comment',
        original_commentable_id: rule_b.id
      )
      expect(review.original_commentable_id).to eq(rule_b.id)
    end
  end

  describe 'export serialization' do
    it 'includes original_rule_id in backup serialization' do
      review = Review.create!(
        rule: rule_a,
        commentable: rule_a,
        user: user,
        action: 'comment',
        comment: 'Moved comment',
        original_commentable_id: rule_b.id
      )

      serializer = Export::Serializers::BackupSerializer.new(component)
      data = serializer.serialize
      exported_review = data[:reviews].find { |r| r[:external_id] == review.id }

      expect(exported_review).to be_present
      expect(exported_review[:original_rule_id]).to eq(rule_b.rule_id)
    end

    it 'exports NULL original_rule_id for direct comments' do
      review = Review.create!(
        rule: rule_a,
        commentable: rule_a,
        user: user,
        action: 'comment',
        comment: 'Direct comment'
      )

      serializer = Export::Serializers::BackupSerializer.new(component)
      data = serializer.serialize
      exported_review = data[:reviews].find { |r| r[:external_id] == review.id }

      expect(exported_review[:original_rule_id]).to be_nil
    end
  end

  describe 'import restoration' do
    let(:result) { Import::Result.new }
    let(:rule_id_map) { { rule_a.rule_id => rule_a.id, rule_b.rule_id => rule_b.id } }

    it 'restores original_commentable_id from original_rule_id on import' do
      reviews_data = [
        {
          'external_id' => 9001,
          'rule_id' => rule_a.rule_id,
          'action' => 'comment',
          'comment' => 'Imported moved comment',
          'user_email' => user.email,
          'user_name' => user.name,
          'original_rule_id' => rule_b.rule_id,
          'created_at' => Time.current.iso8601
        }
      ]

      builder = Import::JsonArchive::ReviewBuilder.new(reviews_data, rule_id_map, result)
      count = builder.build_all

      expect(count).to eq(1)
      imported = Review.where(rule: rule_a).order(:id).last
      expect(imported.original_commentable_id).to eq(rule_b.id)
    end

    it 'leaves original_commentable_id NULL when original_rule_id absent' do
      reviews_data = [
        {
          'external_id' => 9002,
          'rule_id' => rule_a.rule_id,
          'action' => 'comment',
          'comment' => 'Direct comment',
          'user_email' => user.email,
          'user_name' => user.name,
          'created_at' => Time.current.iso8601
        }
      ]

      builder = Import::JsonArchive::ReviewBuilder.new(reviews_data, rule_id_map, result)
      builder.build_all

      imported = Review.where(rule: rule_a).order(:id).last
      expect(imported.original_commentable_id).to be_nil
    end
  end
end
