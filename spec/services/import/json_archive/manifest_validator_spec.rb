# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Import::JsonArchive::ManifestValidator do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let(:project) { create(:project) }
  let(:result) { Import::Result.new }

  def manifest(component_name: 'My Component', srg_id: srg.srg_id, srg_version: srg.version)
    {
      'backup_format_version' => '1.1',
      'srgs' => [],
      'components' => [
        {
          'name' => component_name,
          'srg_id' => srg_id,
          'srg_version' => srg_version,
          'srg_title' => srg.title
        }
      ]
    }
  end

  describe '#validate' do
    context 'with no conflicts' do
      it 'returns a successful result' do
        described_class.new(manifest, project).validate(result)
        expect(result).to be_success
        expect(result.warnings).to be_empty
      end
    end

    context 'when a component name conflict exists' do
      before { create(:component, :skip_rules, project: project, name: 'Conflicting', based_on: srg) }

      it 'errors by default (no merge / dry_run / component_filter)' do
        described_class.new(manifest(component_name: 'Conflicting'), project).validate(result)
        expect(result).not_to be_success
        expect(result.errors.join).to include('Component name conflict')
        expect(result.errors.join).to include('Rename or delete the existing component')
      end

      it 'warns under dry_run' do
        described_class.new(manifest(component_name: 'Conflicting'), project, dry_run: true).validate(result)
        expect(result).to be_success
        expect(result.warnings.join).to include("'Conflicting' already exists")
      end

      it 'warns when a component_filter is supplied' do
        described_class.new(
          manifest(component_name: 'Conflicting'), project, component_filter: ['Conflicting']
        ).validate(result)
        expect(result).to be_success
        expect(result.warnings.join).to include("'Conflicting' already exists")
      end
    end

    # A component entry may list its full source-SRG set (dual-lineage
    # components). Pre-flight must check each one: a missing based_on is
    # already an error above; a missing SECONDARY costs one lineage link,
    # so it surfaces here as a warning — at pre-flight, not only after the
    # component is built.
    context 'when a component entry lists source SRGs' do
      def manifest_with_sources(sources, bundled_srgs: [])
        base = manifest
        base['components'].first['source_srgs'] = sources
        base['srgs'] = bundled_srgs
        base
      end

      def source_entry(srg_record)
        { 'srg_id' => srg_record.srg_id, 'title' => srg_record.title, 'version' => srg_record.version }
      end

      let(:missing_entry) do
        { 'srg_id' => 'SRG-MISSING-SECONDARY', 'title' => 'Missing Secondary', 'version' => 'V1R1' }
      end

      it 'warns at pre-flight when a secondary source is missing from the catalog' do
        described_class.new(
          manifest_with_sources([source_entry(srg), missing_entry]), project
        ).validate(result)

        expect(result).to be_success
        expect(result.warnings.join).to include('SRG-MISSING-SECONDARY')
        expect(result.warnings.join).to include('Missing Secondary')
      end

      it 'does not warn when every listed source is in the catalog' do
        second = create(:security_requirements_guide)
        described_class.new(
          manifest_with_sources([source_entry(srg), source_entry(second)]), project
        ).validate(result)

        expect(result).to be_success
        expect(result.warnings).to be_empty
      end

      it 'does not warn for a missing secondary whose XML is bundled in the archive' do
        described_class.new(
          manifest_with_sources([source_entry(srg), missing_entry],
                                bundled_srgs: [missing_entry]), project
        ).validate(result)

        expect(result).to be_success
        expect(result.warnings).to be_empty
      end
    end
  end
end
