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

      it 'warns in merge mode with an informative message (v2-480.9)' do
        described_class.new(manifest(component_name: 'Conflicting'), project, merge: true).validate(result)
        expect(result).to be_success
        expect(result.errors).to be_empty
        expect(result.warnings.join).to include('Component name conflict in merge mode')
        expect(result.warnings.join).to include('will be merged into existing component')
      end

      it 'prefers the merge warning over dry_run/component_filter wording when merge: true' do
        described_class.new(
          manifest(component_name: 'Conflicting'),
          project,
          merge: true,
          dry_run: true,
          component_filter: ['Conflicting']
        ).validate(result)
        expect(result.warnings.join).to include('merge mode')
      end
    end

    context 'merge kwarg defaults' do
      it 'defaults to false (existing callers see no behavior change)' do
        validator = described_class.new(manifest, project)
        expect(validator.instance_variable_get(:@merge)).to be false
      end
    end
  end
end
