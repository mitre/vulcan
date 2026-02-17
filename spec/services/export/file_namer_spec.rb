# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: FileNamer generates consistent filenames for exports.
# Component filenames include prefix, version, release.
# Project filenames include project name.
# Zip entry names follow the same pattern.
# ==========================================================================
RSpec.describe Export::FileNamer do
  let(:component) { create(:component, name: 'Test Component', prefix: 'TCMP-00', version: 2, release: 3) }
  let(:project) { component.project }

  describe '.component_filename' do
    it 'includes prefix and extension' do
      name = described_class.component_filename(component, '.csv')
      expect(name).to include('TCMP-00')
      expect(name).to end_with('.csv')
    end

    it 'includes version and release' do
      name = described_class.component_filename(component, '.csv')
      expect(name).to include('V2')
      expect(name).to include('R3')
    end
  end

  describe '.project_filename' do
    it 'includes project name and extension' do
      name = described_class.project_filename(project, '.zip')
      expect(name).to include(project.name)
      expect(name).to end_with('.zip')
    end
  end

  describe '.zip_entry_name' do
    it 'includes prefix, version, release, and extension' do
      name = described_class.zip_entry_name(component, '.csv')
      expect(name).to include('TCMP-00')
      expect(name).to include('V2')
      expect(name).to include('R3')
      expect(name).to end_with('.csv')
    end
  end

  describe '.worksheet_name' do
    it 'fits within 31-character Excel limit' do
      long_name_comp = create(:component, name: 'A Very Very Long Component Name That Exceeds Limits',
                                          version: 1, release: 1)
      name = described_class.worksheet_name(long_name_comp)
      expect(name.length).to be <= 31
    end

    it 'includes version, release, and id' do
      name = described_class.worksheet_name(component)
      expect(name).to include("V#{component.version}")
      expect(name).to include("R#{component.release}")
      expect(name).to include(component.id.to_s)
    end
  end
end
