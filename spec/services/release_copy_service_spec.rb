# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT (release copy): releasing an SRG component copies each live,
# non-Not-Applicable authored SrgRule into a fresh CATALOG SrgRule row —
# type stays SrgRule, security_requirements_guide FK set, component FK nil.
# Catalog copies are shaped like uploaded SRG rows: status resets to
# Not Yet Determined (applicability is the downstream STIG author's
# decision), justification and lock/review state reset, content and core
# lineage carry. Tombstoned and Not Applicable rows are never copied — the
# component keeps the NA row and its required justification as the working
# record. The copy is blocked while any live row is still Not Yet
# Determined: every remaining requirement must be decided before release.
# Authored rows stay component-linked and editable after the copy;
# reviews stay on the component's rows. Final derived identifiers mint in
# the release transaction (own-lineage core-half + abbreviation +
# document-wide sequence), stamped on the authored rows so the catalog
# copy carries them and a re-release keeps them byte-identical.
# ==========================================================================
RSpec.describe ReleaseCopyService do
  let_it_be(:core) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RELCOPY', version: 'V1R1')
  end
  let_it_be(:core_rows) do
    %w[SRG-OS-000801 SRG-OS-000802 SRG-OS-000803].map do |version|
      create(:srg_rule, security_requirements_guide: core, version: version)
    end
  end
  let_it_be(:project) { create(:project) }

  def create_source_component(prefix)
    Component.create!(project: project, name: "Release Source #{prefix}",
                      prefix: prefix, title: 'Release copy source', document_type: 'srg',
                      based_on: core)
  end

  def catalog_srg(srg_id)
    create(:security_requirements_guide, :skip_rules, srg_id: srg_id, version: 'V1R1')
  end

  # Decide every live row so the NYD gate passes: first row Applicable
  # with distinctive content, second Not Applicable, third tombstoned.
  def decide_all_rows(component)
    applicable, not_applicable, tombstoned = component.authored_srg_rules.order(:rule_id).to_a
    applicable.update!(status: 'Applicable', fixtext: 'Released fixtext',
                       vendor_comments: 'Released vendor comment', audit_comment: 'release setup')
    applicable.checks.first.update!(content: 'Released check content')
    not_applicable.update!(status: 'Not Applicable',
                           status_justification: 'Out of scope for this technology',
                           audit_comment: 'release setup')
    tombstoned.update_column(:deleted_at, Time.current)
    [applicable, not_applicable, tombstoned]
  end

  describe '#copy!' do
    it 'copies each live non-NA row as a catalog SrgRule — srg FK set, component FK nil, type SrgRule' do
      component = create_source_component('RCPA-01')
      applicable, = decide_all_rows(component)
      catalog = catalog_srg('RELCOPY-D1')

      copied = described_class.new(component, catalog_srg: catalog).copy!

      expect(copied.size).to eq(1)
      row = copied.first
      expect(row).to be_persisted
      expect(row.class).to eq(SrgRule)
      expect(SrgRule.find(row.id).class).to eq(SrgRule)
      expect(row.security_requirements_guide_id).to eq(catalog.id)
      expect(row.component_id).to be_nil
      expect(catalog.srg_rules.count).to eq(1)

      # Content and working ordinals carry; the version is the identifier
      # minted at release, stamped on the authored row and carried here.
      expect(row.fixtext).to eq('Released fixtext')
      expect(row.vendor_comments).to eq('Released vendor comment')
      expect(row.checks.map(&:content)).to eq(['Released check content'])
      expect(row.version).to eq('SRG-OS-000801-RCPA-000001')
      expect(applicable.reload.version).to eq('SRG-OS-000801-RCPA-000001')
      expect(row.rule_id).to eq(applicable.rule_id)
      # Core lineage carries — identifier minting consumes it at release.
      expect(row.derived_from_srg_rule_id).to eq(applicable.derived_from_srg_rule_id)
      expect(row.derived_from_srg_rule_id).not_to be_nil
    end

    it 'excludes tombstoned and Not Applicable rows from the catalog copy' do
      component = create_source_component('RCPA-02')
      _applicable, not_applicable, tombstoned = decide_all_rows(component)
      catalog = catalog_srg('RELCOPY-D2')

      described_class.new(component, catalog_srg: catalog).copy!

      catalog_versions = catalog.srg_rules.pluck(:version)
      expect(catalog_versions).not_to include(not_applicable.version)
      expect(catalog_versions).not_to include(tombstoned.version)
      # The component keeps the NA row and its required justification.
      expect(component.authored_srg_rules.find_by!(rule_id: not_applicable.rule_id)
                      .status_justification).to eq('Out of scope for this technology')
    end

    it 'shapes catalog copies like uploaded rows — status NYD, justification nil, lock and review state reset' do
      component = create_source_component('RCPA-03')
      applicable, = decide_all_rows(component)
      applicable.update!(locked: true, audit_comment: 'release setup')
      catalog = catalog_srg('RELCOPY-D3')

      row = described_class.new(component, catalog_srg: catalog).copy!.first

      expect(row.status).to eq('Not Yet Determined')
      expect(row.status_justification).to be_nil
      expect(row.locked).to be(false)
      expect(row.review_requestor_id).to be_nil
      expect(row.locked_fields).to eq({})
      # The authored row keeps its decided status — the copy never mutates it.
      expect(applicable.reload.status).to eq('Applicable')
    end

    it 'is blocked while any live row is Not Yet Determined and writes nothing' do
      component = create_source_component('RCPA-04')
      # Only decide two of three rows — the third stays live NYD.
      applicable, not_applicable, = component.authored_srg_rules.order(:rule_id).to_a
      applicable.update!(status: 'Applicable', audit_comment: 'release setup')
      not_applicable.update!(status: 'Not Applicable', status_justification: 'Out of scope',
                             audit_comment: 'release setup')
      catalog = catalog_srg('RELCOPY-D4')
      service = described_class.new(component, catalog_srg: catalog)

      expect { service.copy! }.to raise_error(ReleaseCopyService::ReleaseBlockedError,
                                              /Not Yet Determined/)
      expect(catalog.srg_rules.count).to eq(0)
    end

    it 'does not gate on tombstoned NYD rows — only live rows must be decided' do
      component = create_source_component('RCPA-05')
      applicable, not_applicable, undecided = component.authored_srg_rules.order(:rule_id).to_a
      applicable.update!(status: 'Applicable', audit_comment: 'release setup')
      not_applicable.update!(status: 'Not Applicable', status_justification: 'Out of scope',
                             audit_comment: 'release setup')
      undecided.update_column(:deleted_at, Time.current)
      catalog = catalog_srg('RELCOPY-D5')

      expect { described_class.new(component, catalog_srg: catalog).copy! }.not_to raise_error
      expect(catalog.srg_rules.count).to eq(1)
    end

    it 'refuses to run for a non-SRG component' do
      stig_component = create(:component, project: project)
      catalog = catalog_srg('RELCOPY-D6')
      service = described_class.new(stig_component, catalog_srg: catalog)

      expect { service.copy! }.to raise_error(ReleaseCopyService::ReleaseBlockedError,
                                              /SRG component/)
      expect(catalog.srg_rules.count).to eq(0)
    end

    it 'leaves authored rows component-linked and editable, with reviews staying on the component' do
      component = create_source_component('RCPA-07')
      applicable, = decide_all_rows(component)
      user = create(:user)
      Review.create!(user: user, commentable: applicable, action: 'comment',
                     comment: 'Discussion stays on the component')
      catalog = catalog_srg('RELCOPY-D7')

      row = described_class.new(component, catalog_srg: catalog).copy!.first

      # Still component-linked and editable after the copy.
      expect(applicable.reload.component_id).to eq(component.id)
      expect(applicable.update(title: 'Edited after release', audit_comment: 'post-release edit')).to be(true)
      # Reviews stay on the authored row; the catalog copy carries none.
      expect(Review.where(commentable_type: 'BaseRule', commentable_id: applicable.id).count).to eq(1)
      expect(Review.where(commentable_type: 'BaseRule', commentable_id: row.id).count).to eq(0)
      # The catalog row is untouched by the post-copy edit.
      expect(row.reload.title).not_to eq('Edited after release')
    end
  end

  describe 'identifier stability across two releases' do
    it 're-releasing mints identical identifiers for carried requirements; only new ones take new sequence numbers' do
      source = create_source_component('RCPB-01')
      first_row, second_row, third_row = source.authored_srg_rules.order(:rule_id).to_a
      first_row.update!(status: 'Applicable', audit_comment: 'release setup')
      second_row.update!(status: 'Applicable', audit_comment: 'release setup')
      third_row.update!(status: 'Not Applicable', status_justification: 'Out of scope',
                        audit_comment: 'release setup')

      described_class.new(source, catalog_srg: catalog_srg('RELCOPY-S1')).copy!
      expect(source.authored_srg_rules.order(:rule_id).limit(2).pluck(:version))
        .to eq(%w[SRG-OS-000801-RCPB-000001 SRG-OS-000802-RCPB-000002])

      next_version = source.duplicate(new_name: 'RCPB v2')
      next_version.save!
      net_new = create(:srg_rule, :authored, component: next_version, version: nil,
                                             status: 'Not Yet Determined')
      net_new.update!(status: 'Applicable', audit_comment: 'release setup')

      second_catalog = catalog_srg('RELCOPY-S2')
      described_class.new(next_version, catalog_srg: second_catalog).copy!

      published = second_catalog.srg_rules.pluck(:version)
      # Carried requirements keep their published identifiers byte-identical.
      expect(published).to include('SRG-OS-000801-RCPB-000001', 'SRG-OS-000802-RCPB-000002')
      # The net-new requirement takes the next document-wide sequence,
      # abbreviation-only (no lineage) — the NA row never mints.
      expect(published).to include('RCPB-000003')
      expect(published.size).to eq(3)
    end
  end

  describe '#validation_errors' do
    it 'reports the live NYD count without raising' do
      component = create_source_component('RCPA-08')
      catalog = catalog_srg('RELCOPY-D8')

      errors = described_class.new(component, catalog_srg: catalog).validation_errors

      expect(errors.size).to eq(1)
      expect(errors.first).to include('3')
      expect(errors.first).to include('Not Yet Determined')
    end

    it 'requires a catalog SRG target' do
      component = create_source_component('RCPA-09')
      decide_all_rows(component)

      errors = described_class.new(component, catalog_srg: nil).validation_errors

      expect(errors).to eq(['a catalog SRG row is required'])
    end
  end
end
