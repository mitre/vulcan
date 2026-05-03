# frozen_string_literal: true

require 'rails_helper'

# Verify legacy four-value comment_phase values in archive JSON are
# remapped to the current open/closed shape so older backups still
# import cleanly.
RSpec.describe Import::JsonArchive::ComponentBuilder do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let(:project) { create(:project) }
  let(:result) { Import::Result.new }

  def component_data(phase:, reason: nil)
    {
      'name' => "Imported #{SecureRandom.hex(2)}",
      'prefix' => 'IMP-01',
      'version' => '1',
      'release' => '1',
      'title' => 'Imported title',
      'description' => 'desc',
      'released' => false,
      'admin_name' => 'Admin',
      'admin_email' => 'admin@example.com',
      'advanced_fields' => false,
      'comment_phase' => phase,
      'closed_reason' => reason,
      'based_on' => { 'srg_id' => srg.srg_id, 'version' => srg.version, 'title' => srg.title }
    }
  end

  describe 'comment_phase normalization' do
    it 'maps legacy "draft" to open' do
      built = described_class.new(component_data(phase: 'draft'), project, result).build
      expect(built.comment_phase).to eq('open')
      expect(built.closed_reason).to be_nil
    end

    it 'maps legacy "adjudication" to closed+adjudicating' do
      built = described_class.new(component_data(phase: 'adjudication'), project, result).build
      expect(built.comment_phase).to eq('closed')
      expect(built.closed_reason).to eq('adjudicating')
    end

    it 'maps legacy "final" to closed+finalized' do
      built = described_class.new(component_data(phase: 'final'), project, result).build
      expect(built.comment_phase).to eq('closed')
      expect(built.closed_reason).to eq('finalized')
    end

    it 'preserves a current "open" payload as-is' do
      built = described_class.new(component_data(phase: 'open'), project, result).build
      expect(built.comment_phase).to eq('open')
      expect(built.closed_reason).to be_nil
    end

    it 'preserves a current closed+reason payload as-is' do
      built = described_class.new(
        component_data(phase: 'closed', reason: 'finalized'), project, result
      ).build
      expect(built.comment_phase).to eq('closed')
      expect(built.closed_reason).to eq('finalized')
    end

    it 'defaults to open when comment_phase is missing entirely' do
      built = described_class.new(component_data(phase: nil), project, result).build
      expect(built.comment_phase).to eq('open')
      expect(built.closed_reason).to be_nil
    end
  end
end
