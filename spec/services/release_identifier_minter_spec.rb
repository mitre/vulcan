# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT (derived identifier minting): final derived identifiers are
# minted at release, following the published DISA pattern. Each
# requirement's core-half comes from its OWN derived_from lineage (never
# the component's primary parent); the component's abbreviation joins it
# with a 6-digit local sequence (SRG-APP-000014-CTR-000035). The sequence
# counter is DOCUMENT-WIDE — one counter across all core namespaces; the
# sequence identifies the derived requirement, the core-half identifies
# the mapping. A net-new requirement without lineage mints
# ABBREVIATION-SEQUENCE from the same counter (the STIG added-requirement
# pattern). Minted identifiers are stamped on the authored row (audited),
# never re-minted, and their sequence numbers are never reused — even
# after the row is tombstoned. Rows already carrying a minted identifier
# keep it byte-identical.
# ==========================================================================
RSpec.describe ReleaseIdentifierMinter do
  let_it_be(:core_app) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-MINT-APP', version: 'V1R1')
  end
  let_it_be(:core_os) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-MINT-OS', version: 'V1R1')
  end
  let_it_be(:app_rows) do
    %w[SRG-APP-000101 SRG-APP-000102].map do |version|
      create(:srg_rule, security_requirements_guide: core_app, version: version)
    end
  end
  let_it_be(:os_row) do
    create(:srg_rule, security_requirements_guide: core_os, version: 'SRG-OS-000201')
  end
  let_it_be(:project) { create(:project) }

  def single_lineage_component
    Component.create!(project: project, name: "Mint single #{SecureRandom.hex(3)}",
                      prefix: 'MINT-00', title: 'Minting source', document_type: 'srg',
                      based_on: core_app)
  end

  def dual_lineage_component
    Component.create!(project: project, name: "Mint dual #{SecureRandom.hex(3)}",
                      prefix: 'MINT-00', title: 'Minting source', document_type: 'srg',
                      based_on: core_app,
                      declared_source_srg_ids: [core_app.id, core_os.id])
  end

  def decide_applicable(rows)
    rows.each { |row| row.update!(status: 'Applicable', audit_comment: 'mint setup') }
  end

  def publishable_rows(component)
    component.authored_srg_rules.where(deleted_at: nil)
             .where.not(status: 'Not Applicable').canonical_order.to_a
  end

  describe '#mint!' do
    it 'mints core-half from each row\'s own lineage + abbreviation + next sequence, stamped on the authored row' do
      component = single_lineage_component
      rows = publishable_rows(component)
      decide_applicable(rows)
      # Real release state: every row is locked before release — stamping
      # must work on locked rows.
      rows.each { |row| row.update!(locked: true, audit_comment: 'mint setup') }

      described_class.new(component).mint!(rows)

      minted = component.authored_srg_rules.order(:rule_id).map(&:version)
      expect(minted).to eq(%w[SRG-APP-000101-MINT-000001 SRG-APP-000102-MINT-000002])
    end

    it 'mints a dual-lineage set under BOTH core namespaces with the shared abbreviation and ONE document-wide counter' do
      component = dual_lineage_component
      rows = publishable_rows(component)
      expect(rows.size).to eq(3)
      decide_applicable(rows)

      described_class.new(component).mint!(rows)

      minted = component.authored_srg_rules.order(:version).pluck(:version)
      # based_on is the APP core — the OS-derived row still mints under
      # SRG-OS, proving the core-half follows the row's own lineage.
      expect(minted).to eq(%w[SRG-APP-000101-MINT-000001
                              SRG-APP-000102-MINT-000002
                              SRG-OS-000201-MINT-000003])
    end

    it 'mints a net-new requirement without lineage as ABBREVIATION-SEQUENCE from the same counter' do
      component = single_lineage_component
      # version: nil is the authentic net-new shape — direct authoring
      # creates rows with no identifier (the factory default models a
      # catalog row and would look already-minted).
      net_new = create(:srg_rule, :authored, component: component, version: nil,
                                             title: 'Net-new requirement', status: 'Not Yet Determined')
      net_new.update!(status: 'Applicable', audit_comment: 'mint setup')
      rows = publishable_rows(component)
      decide_applicable(rows)

      described_class.new(component).mint!(rows)

      expect(net_new.reload.version).to eq('MINT-000003')
    end

    it 'never re-mints an already-minted row and never reuses a sequence — even from a tombstoned row' do
      component = single_lineage_component
      rows = publishable_rows(component)
      decide_applicable(rows)
      described_class.new(component).mint!(rows)
      first, second = component.authored_srg_rules.order(:rule_id).to_a
      expect(second.version).to eq('SRG-APP-000102-MINT-000002')

      # Re-minting the same set changes nothing.
      described_class.new(component).mint!(publishable_rows(component))
      expect(first.reload.version).to eq('SRG-APP-000101-MINT-000001')

      # Tombstone the seq-2 row, add a new requirement: it takes seq 3,
      # never the retired 2.
      second.update_column(:deleted_at, Time.current)
      net_new = create(:srg_rule, :authored, component: component, version: nil,
                                             status: 'Not Yet Determined')
      net_new.update!(status: 'Applicable', audit_comment: 'mint setup')

      described_class.new(component).mint!(publishable_rows(component))

      expect(net_new.reload.version).to eq('MINT-000003')
      expect(first.reload.version).to eq('SRG-APP-000101-MINT-000001')
    end

    it 'keeps published identifiers byte-identical even after the component abbreviation changes' do
      component = single_lineage_component
      rows = publishable_rows(component)
      decide_applicable(rows)
      described_class.new(component).mint!(rows)

      component.update!(prefix: 'ZZZZ-00')
      net_new = create(:srg_rule, :authored, component: component, version: nil,
                                             status: 'Not Yet Determined')
      net_new.update!(status: 'Applicable', audit_comment: 'mint setup')

      described_class.new(component).mint!(publishable_rows(component))

      expect(component.authored_srg_rules.order(:rule_id).pluck(:version))
        .to eq(%w[SRG-APP-000101-MINT-000001 SRG-APP-000102-MINT-000002 ZZZZ-000003])
    end

    describe 'audit trail' do
      include_context 'with auditing'

      it 'records the mint as an audited system change on the authored row' do
        component = single_lineage_component
        rows = publishable_rows(component)
        decide_applicable(rows)

        described_class.new(component).mint!(rows)

        audit = rows.first.reload.audits.reorder(:created_at).last
        expect(audit.audited_changes['version'].last).to eq('SRG-APP-000101-MINT-000001')
        expect(audit.comment).to eq('Identifier minted at release')
      end
    end

    # Real DISA container SRGs number requirements with a 5-segment core
    # (SRG-APP-000014-CTR-000035), not the 3-segment form the older specs
    # use. A minted id built from a 5-segment core must still be recognized
    # as minted on the next release, or the never-renumber invariant breaks.
    describe 'with 5-segment (container) SRG cores' do
      let_it_be(:core_ctr) do
        create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-MINT-CTR', version: 'V1R1')
      end
      let_it_be(:ctr_rows) do
        %w[SRG-APP-000014-CTR-000035 SRG-APP-000023-CTR-000090].map do |version|
          create(:srg_rule, security_requirements_guide: core_ctr, version: version)
        end
      end

      def ctr_component
        Component.create!(project: project, name: "Mint ctr #{SecureRandom.hex(3)}",
                          prefix: 'MINT-00', title: 'Minting source', document_type: 'srg',
                          based_on: core_ctr)
      end

      it 'mints 5-segment cores and carries them forward byte-identical on re-release' do
        component = ctr_component
        rows = publishable_rows(component)
        decide_applicable(rows)
        described_class.new(component).mint!(rows)

        first, second = component.authored_srg_rules.order(:rule_id).to_a
        expect(first.version).to eq('SRG-APP-000014-CTR-000035-MINT-000001')
        expect(second.version).to eq('SRG-APP-000023-CTR-000090-MINT-000002')

        # Re-mint the same set: already-minted 5-segment ids must be
        # recognized and left untouched (this is where the shape-only
        # recognition failed — minted? returned false and renumbered).
        described_class.new(component).mint!(publishable_rows(component))
        expect(first.reload.version).to eq('SRG-APP-000014-CTR-000035-MINT-000001')
        expect(second.reload.version).to eq('SRG-APP-000023-CTR-000090-MINT-000002')
      end

      it 'never reuses a retired sequence when a 5-segment-core row is tombstoned' do
        component = ctr_component
        rows = publishable_rows(component)
        decide_applicable(rows)
        described_class.new(component).mint!(rows)
        first, second = component.authored_srg_rules.order(:rule_id).to_a
        expect(second.version).to eq('SRG-APP-000023-CTR-000090-MINT-000002')

        # Tombstone seq-2 and add a net-new requirement: it must take seq 3,
        # never the retired 2, and the surviving published id must not move.
        second.update_column(:deleted_at, Time.current)
        net_new = create(:srg_rule, :authored, component: component, version: nil,
                                               status: 'Not Yet Determined')
        net_new.update!(status: 'Applicable', audit_comment: 'mint setup')

        described_class.new(component).mint!(publishable_rows(component))

        expect(net_new.reload.version).to eq('MINT-000003')
        expect(first.reload.version).to eq('SRG-APP-000014-CTR-000035-MINT-000001')
      end
    end
  end
end
