# frozen_string_literal: true

require 'rails_helper'

# ===========================================================================
# REQUIREMENT: the disposition matrix is kind-agnostic. An SRG component
# stores its requirements as authored SrgRules, so every requirement-scoped
# query in the export must go through the kind seam
# (BaseRule.live_for_components) — querying Rule (the STIG STI subclass)
# silently omits every SRG requirement's comments from the export, and a
# disposition matrix that silently loses public comments is a data-loss
# defect, not a rendering nit.
# ===========================================================================
RSpec.describe DispositionMatrixExport do
  let_it_be(:project) { create(:project) }
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    prefix: 'DSPX-00', name: 'Disposition SRG', title: 'Disposition SRG')
  end
  let_it_be(:authored_row) do
    create(:srg_rule, :authored, component: srg_component, rule_id: '000001',
                                 status: 'Applicable', title: 'Authored requirement under comment')
  end
  let_it_be(:commenter) do
    user = create(:user, name: 'SRG Commenter')
    Membership.find_or_create_by!(user: user, membership: project) { |m| m.role = 'viewer' }
    user
  end
  let_it_be(:srg_comment) do
    create(:review, :comment, user: commenter, rule: nil, commentable: authored_row,
                              comment: 'Comment on an authored SRG requirement', section: 'fixtext')
  end

  describe '.records_exist?' do
    it 'sees a comment on an authored SRG requirement' do
      expect(described_class.records_exist?(srg_component)).to be true
    end
  end

  describe '.top_level_reviews' do
    it 'includes comments on authored SRG requirements' do
      reviews = described_class.top_level_reviews(srg_component, nil)
      expect(reviews.map(&:comment)).to include('Comment on an authored SRG requirement')
    end
  end

  describe '.top_level_reviews_for_components' do
    it 'groups an SRG requirement comment under its owning component' do
      grouped = described_class.top_level_reviews_for_components([srg_component], nil)
      expect(grouped[srg_component.id].map(&:comment))
        .to include('Comment on an authored SRG requirement')
    end
  end

  # live_for_components excludes soft-deleted requirements, so a tombstoned
  # (e.g. relocated-away) requirement's comments leave the export. That is
  # the seam's documented semantics — pinned here so the exclusion stays a
  # decision, not an accident of the query.
  describe 'soft-deleted requirements' do
    it 'excludes their comments from the disposition rows' do
      tombstoned = create(:srg_rule, :authored, component: srg_component, rule_id: '000099',
                                                status: 'Applicable', title: 'Tombstoned requirement')
      create(:review, :comment, user: commenter, rule: nil, commentable: tombstoned,
                                comment: 'Comment on a tombstoned requirement', section: 'fixtext')
      tombstoned.update!(deleted_at: Time.current)

      comments = described_class.top_level_reviews(srg_component, nil).map(&:comment)
      expect(comments).not_to include('Comment on a tombstoned requirement')
      expect(comments).to include('Comment on an authored SRG requirement')
    end
  end

  describe '.generate' do
    it 'emits the SRG requirement comment as a disposition row with its requirement identity' do
      out = CSV.parse(described_class.generate(component: srg_component), headers: true)
      row = out.find { |r| r['Comment'] == 'Comment on an authored SRG requirement' }

      expect(row).not_to be_nil, 'SRG requirement comment missing from the disposition CSV'
      expect(row['Rule']).to eq('DSPX-00-000001')
      expect(row['Section']).to eq('fixtext')
    end
  end
end
