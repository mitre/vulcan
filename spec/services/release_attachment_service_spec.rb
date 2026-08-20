# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT (release attachment, registry pattern): releasing an SRG
# component creates its catalog SecurityRequirementsGuide row by
# generating the published XCCDF FIRST (minted identifiers stamped
# before generation) and deriving the row's columns FROM that artifact —
# the stored document is authoritative, the columns are its projection.
# Rules come from the release copy, never the XML import. The released
# entry behaves exactly like an uploaded SRG: basing and is-latest work
# unchanged. The whole attachment is one transaction. The changelog is
# structured removals data (from executed relocation records) plus a
# plain-text rendering.
# ==========================================================================
RSpec.describe ReleaseAttachmentService do
  let_it_be(:core) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-RATT', version: 'V1R1')
  end
  let_it_be(:core_rows) do
    %w[SRG-OS-000831 SRG-OS-000832].map do |version|
      create(:srg_rule, security_requirements_guide: core, version: version)
    end
  end
  let_it_be(:project) { create(:project) }

  def build_releasable_component(name: 'Release Attachment Source', prefix: 'RATT-00',
                                 version: 1, release: 1)
    component = Component.create!(project: project, name: name, prefix: prefix,
                                  title: 'Release attachment source', document_type: 'srg',
                                  based_on: core, version: version, release: release)
    applicable, not_applicable = component.authored_srg_rules.order(:rule_id).to_a
    applicable.update!(status: 'Applicable', fixtext: 'Attachment fix text', audit_comment: 'setup')
    not_applicable.update!(status: 'Not Applicable', status_justification: 'Out of scope',
                           audit_comment: 'setup')
    [component, applicable, not_applicable]
  end

  describe '#attach!' do
    it 'creates the catalog row with columns derived from its own exported XCCDF — rules from the copy' do
      component, applicable, = build_releasable_component

      catalog = described_class.new(component).attach!

      # Columns are the projection of the stored artifact.
      header = SecurityRequirementsGuide.header_fields(catalog.xml)
      expect(catalog.srg_id).to eq('Release_Attachment_Source')
      expect(catalog.title).to eq('Release attachment source')
      expect(catalog.version).to eq('V1R1')
      expect(catalog.name).to eq('Release Attachment Source - Ver 1, Rel 1')
      expect(catalog.release_date).to eq(Time.zone.today)
      expect(catalog.core).to be(false)
      expect(header).to eq(srg_id: 'Release_Attachment_Source', title: 'Release attachment source',
                           version: 'V1R1', release_date: Time.zone.today)

      # Rules came from the release copy, never the XML import: the NA row
      # is excluded, and lineage — which a parsed XML cannot carry — is on
      # the catalog copy.
      expect(catalog.srg_rules.count).to eq(1)
      copy = catalog.srg_rules.first
      expect(copy.derived_from_srg_rule_id).to eq(applicable.derived_from_srg_rule_id)
      expect(copy.status).to eq('Not Yet Determined')
      expect(copy.component_id).to be_nil

      # Uploaded shape all the way down: the catalog row's rule_id is the
      # artifact's Rule element id — the join key the basing import uses.
      expect(copy.rule_id).to eq("SV-RATT-00-#{applicable.rule_id}")
      expect(catalog.xml).to include(%(Rule id="SV-RATT-00-#{applicable.rule_id}"))
    end

    it 'mints identifiers BEFORE generating the XCCDF — the stored artifact carries the minted ids' do
      component, applicable, = build_releasable_component(name: 'Mint Order Source', prefix: 'MNTO-00')

      catalog = described_class.new(component).attach!

      applicable.reload
      expect(applicable.version).to eq('SRG-OS-000831-MNTO-000001')
      expect(catalog.xml).to include('SRG-OS-000831-MNTO-000001')
      expect(catalog.srg_rules.first.version).to eq('SRG-OS-000831-MNTO-000001')
    end

    it 'released entries behave like uploaded ones — basing works and is-latest tracks releases' do
      component, = build_releasable_component(name: 'Latest Track Source', prefix: 'LTRK-00')
      service = described_class.new(component)
      first_release = service.attach!
      expect(first_release.latest?).to be(true)

      component.update!(release: 2, audit_comment: 'next release')
      second_release = described_class.new(component).attach!

      expect(second_release.version).to eq('V1R2')
      expect(second_release.latest?).to be(true)
      expect(first_release.latest?).to be(false)

      based = Component.create!(project: project, name: 'Based on released', prefix: 'BSRL-00',
                                title: 'Based on the released entry', based_on: second_release)
      expect(based.rules.count).to eq(1)
    end

    it 'is one transaction — a failure inside leaves no catalog row and no copies' do
      component, = build_releasable_component(name: 'Atomic Source', prefix: 'ATOM-00')
      described_class.new(component).attach!
      rows_after_first = SrgRule.unscoped.count

      # Same component version again — the catalog uniqueness (srg_id,
      # version) fails INSIDE the transaction, after minting and copying
      # would have run.
      expect { described_class.new(component).attach! }.to raise_error(ActiveRecord::RecordInvalid)

      expect(SecurityRequirementsGuide.where(srg_id: 'Atomic_Source').count).to eq(1)
      expect(SrgRule.unscoped.count).to eq(rows_after_first)
    end
  end

  describe '#validation_errors' do
    it 'refuses a component missing version or release — never a fabricated default' do
      component, = build_releasable_component(name: 'No Version Source', prefix: 'NOVR-00',
                                              version: nil, release: nil)
      service = described_class.new(component)

      expect(service.validation_errors.join).to include('version and release')
      expect { service.attach! }.to raise_error(described_class::ReleaseBlockedError)
      expect(SecurityRequirementsGuide.exists?(srg_id: 'No_Version_Source')).to be(false)
    end

    it 'surfaces the component-side release blocks — kind and undecided rows' do
      component, applicable, = build_releasable_component(name: 'Undecided Source', prefix: 'UNDC-00')
      applicable.update!(status: 'Not Yet Determined', audit_comment: 'setup')

      errors = described_class.new(component).validation_errors
      expect(errors.join).to include('Not Yet Determined')
    end
  end

  describe 'changelog' do
    it 'reports no removals when no relocation was executed' do
      component, = build_releasable_component(name: 'Quiet Changelog Source', prefix: 'QCLG-00')
      service = described_class.new(component)

      expect(service.changelog_data[:removals]).to eq([])
      expect(service.changelog_data[:version]).to eq('V1R1')
      expect(service.changelog_text).to include('No requirements were removed in this release.')
    end

    it 'includes executed relocations as removals — identifier, destination abbreviation, date' do
      component, applicable, = build_releasable_component(name: 'Moved Changelog Source', prefix: 'MCLG-00')
      moved = create(:srg_rule, :authored, component: component, version: 'SRG-OS-000832-MCLG-000009',
                                           rule_id: '000777', status: 'Applicable')
      moved.update_column(:deleted_at, Time.current)
      RequirementRelocation.create!(source_rule: moved, target_technology_token: 'WEB',
                                    executed_at: Time.zone.local(2026, 7, 20, 12, 0, 0))

      data = described_class.new(component).changelog_data
      expect(data[:removals]).to eq([
                                      { identifier: 'SRG-OS-000832-MCLG-000009',
                                        destination_abbreviation: 'WEB',
                                        executed_on: Date.new(2026, 7, 20) }
                                    ])
      text = described_class.new(component).changelog_text
      expect(text).to include('SRG-OS-000832-MCLG-000009 relocated to WEB (2026-07-20)')
      expect(applicable.reload.deleted_at).to be_nil
    end
  end
end
