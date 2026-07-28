# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT (published SRG export): exporting an SRG-kind component
# emits its authored SrgRules — never an empty benchmark. Terminal
# filtering: ONLY Applicable rows publish; Not Applicable, Not Yet
# Determined, and tombstoned rows are excluded. The emit shape follows
# the published DISA SRG document shape (decided against the seeded GPOS
# document): Group id keeps the working convention (V-PREFIX-rule_id),
# Group title carries the core-half from the row's own lineage (a
# net-new row emits its minted identifier — never an empty title), the
# Rule version element carries the minted identifier, and the srg
# emission includes the conformance bits from day one: GroupDescription
# wrapper, a fix element paired with fixtext, and check-content-ref
# before check-content. STIG emission is byte-locked by the corpus and
# unchanged.
# ==========================================================================
RSpec.describe Export::Modes::PublishedSrg do
  let_it_be(:core) do
    create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-CORE-PSRG', version: 'V1R1')
  end
  let_it_be(:core_rows) do
    %w[SRG-OS-000811 SRG-OS-000812 SRG-OS-000813 SRG-OS-000814].map do |version|
      create(:srg_rule, security_requirements_guide: core, version: version)
    end
  end
  let_it_be(:project) { create(:project) }

  def build_release_ready_component
    component = Component.create!(project: project, name: 'Published SRG Source',
                                  prefix: 'PSRG-00', title: 'Published SRG export source',
                                  document_type: 'srg', based_on: core)
    applicable, not_applicable, tombstoned, undetermined = component.authored_srg_rules.order(:rule_id).to_a
    applicable.update!(status: 'Applicable', fixtext: 'Published fix text', audit_comment: 'setup')
    applicable.checks.first.update!(content: 'Published check content')
    not_applicable.update!(status: 'Not Applicable', status_justification: 'Out of scope',
                           audit_comment: 'setup')
    tombstoned.update!(status: 'Applicable', audit_comment: 'setup')
    tombstoned.update_column(:deleted_at, Time.current)
    # undetermined stays NYD — terminal filtering must exclude it.
    net_new = create(:srg_rule, :authored, component: component, version: nil,
                                           title: 'Net-new published requirement',
                                           status: 'Not Yet Determined')
    net_new.update!(status: 'Applicable', audit_comment: 'setup')
    # Mint like the release flow does — published identifiers.
    ReleaseIdentifierMinter.new(component).mint!([applicable, net_new])
    [component, applicable, not_applicable, tombstoned, undetermined, net_new]
  end

  def export_xml(component)
    Export::Base.new(exportable: component, mode: :published_srg, format: :xccdf).call.data
  end

  it 'emits authored SrgRules with only Applicable rows — NA, NYD, and tombstones excluded' do
    component, applicable, not_applicable, tombstoned, undetermined, net_new = build_release_ready_component

    xml = export_xml(component)
    doc = Ox.parse(xml)
    benchmark = doc.nodes.last
    groups = benchmark.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'Group' }

    expect(groups.size).to eq(2)
    expect(xml).to include(applicable.reload.version)
    expect(xml).to include(net_new.reload.version)
    expect(xml).not_to include(not_applicable.version)
    expect(xml).not_to include(tombstoned.reload.version)
    expect(xml).not_to include(undetermined.version)
    expect(xml).not_to include('Satisfies')
  end

  it 'shapes the emission per the published SRG document shape — ids, titles, version, conformance bits' do
    component, applicable, = build_release_ready_component
    applicable.reload

    xml = export_xml(component)
    doc = Ox.parse(xml)
    benchmark = doc.nodes.last
    group = benchmark.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'Group' }
    rule = group.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'Rule' }

    # Working-convention ids (DISA assigns real numbers at publication).
    expect(group['id']).to eq("V-PSRG-00-#{applicable.rule_id}")
    expect(rule['id']).to eq("SV-PSRG-00-#{applicable.rule_id}")

    # Group title = the core-half from the row's own lineage.
    group_title = group.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'title' }
    expect(group_title.text).to eq('SRG-OS-000811')

    # GroupDescription wrapper present on the srg emission.
    group_desc = group.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'description' }
    expect(group_desc.text).to eq('<GroupDescription></GroupDescription>')

    # Rule version element = the minted identifier.
    rule_version = rule.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'version' }
    expect(rule_version.text).to eq(applicable.version)
    expect(applicable.version).to eq('SRG-OS-000811-PSRG-000001')

    # fix element paired with fixtext, working-convention check ids, and
    # check-content-ref before check-content.
    fixtext = rule.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'fixtext' }
    fix = rule.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'fix' }
    expect(fixtext['fixref']).to eq("F-PSRG-00-#{applicable.rule_id}_fix")
    expect(fix['id']).to eq("F-PSRG-00-#{applicable.rule_id}_fix")
    check = rule.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'check' }
    expect(check['system']).to eq("C-PSRG-00-#{applicable.rule_id}_chk")
    ref, content = check.nodes.select { |n| n.is_a?(Ox::Element) }
    expect(ref.name).to eq('check-content-ref')
    expect(ref['href']).to eq('Published_SRG_Source_SRG.xml')
    expect(ref['name']).to eq('M')
    expect(content.name).to eq('check-content')
    expect(content.text).to eq('Published check content')
  end

  it 'emits the minted identifier as the Group title for a net-new requirement without lineage' do
    component, _applicable, _na, _tomb, _nyd, net_new = build_release_ready_component
    net_new.reload

    xml = export_xml(component)
    doc = Ox.parse(xml)
    benchmark = doc.nodes.last
    groups = benchmark.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'Group' }
    net_new_group = groups.find { |g| g['id'] == "V-PSRG-00-#{net_new.rule_id}" }

    title = net_new_group.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'title' }
    expect(title.text).to eq(net_new.version)
    expect(net_new.version).to eq('PSRG-000002')
  end

  it 'emits the working display name for an unminted net-new row — never empty title or version elements' do
    component = Component.create!(project: project, name: 'Preview SRG Source',
                                  prefix: 'PSRG-00', title: 'Pre-release preview',
                                  document_type: 'srg', based_on: core)
    component.authored_srg_rules.each { |r| r.update!(status: 'Applicable', audit_comment: 'setup') }
    net_new = create(:srg_rule, :authored, component: component, version: nil, rule_id: nil,
                                           status: 'Not Yet Determined')
    net_new.update!(status: 'Applicable', audit_comment: 'setup')
    # No minting — the pre-release working export.

    xml = export_xml(component)
    doc = Ox.parse(xml)
    benchmark = doc.nodes.last
    group = benchmark.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'Group' }
                     .find { |g| g['id'] == "V-PSRG-00-#{net_new.rule_id}" }
    title = group.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'title' }
    rule = group.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'Rule' }
    version = rule.nodes.find { |n| n.is_a?(Ox::Element) && n.name == 'version' }

    expect(title.text).to eq("PSRG-00-#{net_new.rule_id}")
    expect(version.text).to eq("PSRG-00-#{net_new.rule_id}")
  end

  it 'profile select lists track the emitted Groups only — excluded rows never appear' do
    component, applicable, = build_release_ready_component

    xml = export_xml(component)
    benchmark = Ox.parse(xml).nodes.last
    group_ids = benchmark.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'Group' }.pluck('id')
    profiles = benchmark.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'Profile' }

    expect(group_ids.size).to eq(2)
    expect(group_ids).to include("V-PSRG-00-#{applicable.rule_id}")
    expect(profiles.size).to eq(9)
    profiles.each do |profile|
      idrefs = profile.nodes.select { |n| n.is_a?(Ox::Element) && n.name == 'select' }.map { |s| s['idref'] }
      expect(idrefs).to eq(group_ids)
    end
  end

  describe 'XCCDF 1.1.4 schema validation' do
    def xccdf_schema
      # Relative schema imports resolve against the working directory.
      Dir.chdir(Rails.root.join('spec/fixtures/schemas/xccdf/1.1')) do
        Nokogiri::XML::Schema(File.read('xccdf-schema.xsd'))
      end
    end

    it 'anchors the vendored schema set against the published GPOS seed — zero errors' do
      doc = Nokogiri::XML(Rails.root.join('db/seeds/srgs/U_GPOS_SRG_V3R3_Manual-xccdf.xml').read)
      expect(xccdf_schema.validate(doc).map(&:message)).to eq([])
    end

    it 'the published SRG emission schema-validates' do
      component, = build_release_ready_component
      doc = Nokogiri::XML(export_xml(component))
      expect(xccdf_schema.validate(doc).map(&:message)).to eq([])
    end
  end

  it 'is registered for xccdf only' do
    expect(Export::Registry.valid?(:published_srg, :xccdf)).to be(true)
    expect(Export::Registry.valid?(:published_srg, :csv)).to be(false)
    expect(Export::Registry.valid?(:published_srg, :inspec)).to be(false)
  end
end
