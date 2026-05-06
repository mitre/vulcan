# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reaction do
  let_it_be(:srg) do
    srg_xml = Rails.root.join('db/seeds/srgs/U_Web_Server_SRG_V4R4_Manual-xccdf.xml').read
    parsed = Xccdf::Benchmark.parse(srg_xml)
    s = SecurityRequirementsGuide.from_mapping(parsed)
    s.xml = srg_xml
    s.save!
    s
  end
  let_it_be(:project) { Project.create!(name: 'P-react') }
  let_it_be(:component) do
    Component.create!(project: project, name: 'C', title: 'C STIG', version: 'C V1R1',
                      prefix: 'CRCT-01', based_on: srg)
  end
  let_it_be(:rule) do
    Rule.create!(component: component, rule_id: 'CRCT-01-000001', status: 'Applicable - Configurable',
                 rule_severity: 'medium', srg_rule: srg.srg_rules.first)
  end
  let_it_be(:reactor) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  before { Membership.find_or_create_by!(user: reactor, membership: project) { |m| m.role = 'viewer' } }

  let(:comment_review) do
    Review.create!(action: 'comment', comment: 'a comment', user: reactor, rule: rule)
  end

  describe 'KINDS' do
    it 'is the frozen list up/down' do
      expect(described_class::KINDS).to eq(%w[up down])
      expect(described_class::KINDS).to be_frozen
    end
  end

  describe 'associations' do
    it 'belongs_to :review' do
      r = described_class.new(review: comment_review, user: reactor, kind: 'up')
      expect(r.review).to eq(comment_review)
    end

    it 'belongs_to :user' do
      r = described_class.new(review: comment_review, user: reactor, kind: 'up')
      expect(r.user).to eq(reactor)
    end
  end

  describe 'validations' do
    it 'rejects an unknown kind' do
      r = described_class.new(review: comment_review, user: reactor, kind: 'meh')
      expect(r.valid?).to be(false)
      expect(r.errors[:kind].join).to match(/included/i)
    end

    it 'accepts up' do
      r = described_class.new(review: comment_review, user: reactor, kind: 'up')
      expect(r.valid?).to be(true)
    end

    it 'accepts down' do
      r = described_class.new(review: comment_review, user: reactor, kind: 'down')
      expect(r.valid?).to be(true)
    end

    it 'rejects a duplicate (user, review) pair' do
      described_class.create!(review: comment_review, user: reactor, kind: 'up')
      dup = described_class.new(review: comment_review, user: reactor, kind: 'down')
      expect(dup.valid?).to be(false)
      expect(dup.errors[:user_id].join).to match(/already reacted/i)
    end

    it 'allows two different users to react to the same review' do
      described_class.create!(review: comment_review, user: reactor, kind: 'up')
      r = described_class.new(review: comment_review, user: other_user, kind: 'down')
      expect(r.valid?).to be(true)
    end

    it 'rejects a reaction on a non-comment review' do
      non_comment = comment_review
      non_comment.update_columns(action: 'approve')
      r = described_class.new(review: non_comment, user: reactor, kind: 'up')
      expect(r.valid?).to be(false)
      expect(r.errors[:review].join).to match(/comment-action/i)
    end

    it 'allows a reaction on a reply (Decision 7)' do
      parent = comment_review
      reply = Review.create!(action: 'comment', comment: 'reply', user: reactor, rule: rule,
                             responding_to_review_id: parent.id)
      r = described_class.new(review: reply, user: other_user, kind: 'up')
      expect(r.valid?).to be(true)
    end
  end

  describe 'cascade behavior' do
    it 'destroys reactions when the parent review is destroyed' do
      r = described_class.create!(review: comment_review, user: reactor, kind: 'up')
      expect { comment_review.destroy }.to change { described_class.exists?(id: r.id) }.from(true).to(false)
    end

    it 'destroys reactions when the user is destroyed' do
      doomed = create(:user)
      Membership.create!(user: doomed, membership: project, role: 'viewer')
      r = described_class.create!(review: comment_review, user: doomed, kind: 'up')
      expect { doomed.destroy }.to change { described_class.exists?(id: r.id) }.from(true).to(false)
    end
  end

  describe '.summary' do
    let_it_be(:second_review) do
      Review.create!(action: 'comment', comment: 'second', user: reactor, rule: rule)
    end

    it 'returns an empty hash when given an empty array' do
      expect(described_class.summary([])).to eq({})
    end

    it 'returns zero counts and nil mine for a review with no reactions' do
      expect(described_class.summary([comment_review.id], reactor.id)).to eq(
        comment_review.id => { up: 0, down: 0, mine: nil }
      )
    end

    it 'returns aggregated counts across multiple reviews' do
      described_class.create!(review: comment_review, user: reactor, kind: 'up')
      described_class.create!(review: comment_review, user: other_user, kind: 'up')
      described_class.create!(review: second_review, user: reactor, kind: 'down')

      expect(described_class.summary([comment_review.id, second_review.id])).to include(
        comment_review.id => { up: 2, down: 0, mine: nil },
        second_review.id => { up: 0, down: 1, mine: nil }
      )
    end

    it 'sets mine to the current user kind when reactor matches' do
      described_class.create!(review: comment_review, user: reactor, kind: 'up')

      expect(described_class.summary([comment_review.id], reactor.id)[comment_review.id])
        .to eq(up: 1, down: 0, mine: 'up')
    end

    it 'sets mine to nil when current user has not reacted' do
      described_class.create!(review: comment_review, user: other_user, kind: 'down')

      expect(described_class.summary([comment_review.id], reactor.id)[comment_review.id])
        .to eq(up: 0, down: 1, mine: nil)
    end

    it 'omits mine plumbing entirely when current_user_id is nil' do
      described_class.create!(review: comment_review, user: reactor, kind: 'up')

      expect(described_class.summary([comment_review.id], nil)[comment_review.id])
        .to eq(up: 1, down: 0, mine: nil)
    end
  end

  describe 'audit trail' do
    it 'writes an audit row on create' do
      review = comment_review
      expect do
        described_class.create!(review: review, user: reactor, kind: 'up')
      end.to change(Audited::Audit, :count).by(1)
    end

    it 'writes an audit row when kind toggles up → down' do
      reaction = described_class.create!(review: comment_review, user: reactor, kind: 'up')
      expect { reaction.update!(kind: 'down') }.to change(Audited::Audit, :count).by(1)
    end

    it 'writes an audit row on destroy (toggle off)' do
      reaction = described_class.create!(review: comment_review, user: reactor, kind: 'up')
      expect { reaction.destroy }.to change(Audited::Audit, :count).by(1)
    end
  end
end
