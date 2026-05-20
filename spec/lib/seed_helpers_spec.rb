# frozen_string_literal: true

require 'rails_helper'
require_relative '../../lib/seed_helpers'

RSpec.describe SeedHelpers do
  before do
    Rails.application.reload_routes!
  end

  describe '.seed_xccdf' do
    let(:srg_path) { Rails.root.join('db/seeds/srgs').glob('*GPOS*.xml').first }

    it 'creates an SRG from an XCCDF XML file' do
      expect { described_class.seed_xccdf(srg_path) }
        .to change(SecurityRequirementsGuide, :count).by(1)
    end

    it 'is idempotent — second call does not duplicate' do
      described_class.seed_xccdf(srg_path)
      expect { described_class.seed_xccdf(srg_path) }
        .not_to change(SecurityRequirementsGuide, :count)
    end
  end

  describe '.seed_component' do
    let!(:srg) { described_class.seed_xccdf(Rails.root.join('db/seeds/srgs').glob('*GPOS*.xml').first) }
    let!(:project) { create(:project) }

    it 'creates a component with required attributes' do
      component = described_class.seed_component(
        project: project, name: 'Test OS', title: 'Test STIG Guide',
        prefix: 'TEST-01', based_on: srg,
        admin_name: 'Tester', admin_email: 'test@example.com'
      )
      expect(component).to be_persisted
      expect(component.name).to eq('Test OS')
      expect(component.admin_name).to eq('Tester')
    end

    it 'is idempotent — second call returns existing record' do
      attrs = { project: project, name: 'Idem OS', title: 'Idem Guide',
                prefix: 'IDEM-01', based_on: srg,
                admin_name: 'Tester', admin_email: 'test@example.com' }
      described_class.seed_component(**attrs)
      expect { described_class.seed_component(**attrs) }
        .not_to change(Component, :count)
    end
  end

  describe '.find_or_seed_review' do
    let!(:srg) { described_class.seed_xccdf(Rails.root.join('db/seeds/srgs').glob('*GPOS*.xml').first) }
    let!(:project) { create(:project) }
    let!(:component) { create(:component, project: project, based_on: srg) }
    let!(:user) { create(:user) }
    let!(:membership) { create(:membership, user: user, membership: project, role: 'viewer') }
    let(:rule) { component.rules.first }

    it 'creates a review comment via Review.create!' do
      review = described_class.find_or_seed_review(
        rule: rule, user: user, section: 'check_content',
        comment: 'Test comment for seed helper'
      )
      expect(review).to be_persisted
      expect(review.action).to eq('comment')
      expect(review.triage_status).to eq('pending')
    end

    it 'is idempotent — finds existing by comment text' do
      described_class.find_or_seed_review(
        rule: rule, user: user, section: 'check_content',
        comment: 'Idempotent test comment'
      )
      expect do
        described_class.find_or_seed_review(
          rule: rule, user: user, section: 'check_content',
          comment: 'Idempotent test comment'
        )
      end.not_to change(Review, :count)
    end
  end

  describe '.find_or_seed_reply' do
    let!(:srg) { described_class.seed_xccdf(Rails.root.join('db/seeds/srgs').glob('*GPOS*.xml').first) }
    let!(:project) { create(:project) }
    let!(:component) { create(:component, project: project, based_on: srg) }
    let!(:user) { create(:user) }
    let!(:membership) { create(:membership, user: user, membership: project, role: 'viewer') }
    let(:rule) { component.rules.first }

    it 'creates a reply linked to parent' do
      parent = described_class.find_or_seed_review(
        rule: rule, user: user, section: 'check_content', comment: 'Parent'
      )
      reply = described_class.find_or_seed_reply(
        parent: parent, user: user, comment: 'Reply text'
      )
      expect(reply).to be_persisted
      expect(reply.responding_to_review_id).to eq(parent.id)
    end

    it 'is idempotent — finds existing by parent + comment' do
      parent = described_class.find_or_seed_review(
        rule: rule, user: user, section: 'fixtext', comment: 'Parent 2'
      )
      described_class.find_or_seed_reply(parent: parent, user: user, comment: 'Reply 2')
      expect do
        described_class.find_or_seed_reply(parent: parent, user: user, comment: 'Reply 2')
      end.not_to change(Review, :count)
    end
  end

  describe '.status_report' do
    it 'returns a hash of model counts' do
      report = described_class.status_report
      expect(report).to include(:users, :projects, :srgs, :stigs, :components, :rules, :memberships, :comments, :replies)
      expect(report[:users]).to eq(User.count)
    end
  end

  describe '.verify!' do
    it 'returns an array of error strings' do
      errors = described_class.verify!
      expect(errors).to be_an(Array)
    end
  end
end
