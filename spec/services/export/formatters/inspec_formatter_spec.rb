# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: InspecFormatter generates a zip archive containing inspec.yml
# and controls/*.rb for each component. Multi-component exports produce
# subdirectories within a single zip. Uses rule.inspec_control_file for
# the Ruby control file content.
# ==========================================================================
RSpec.describe Export::Formatters::InspecFormatter do
  subject(:formatter) { described_class.new }

  let(:status_ac) { 'Applicable - Configurable' }
  let(:inspec_yml) { 'inspec.yml' }

  describe '#component_based?' do
    it 'returns true' do
      expect(formatter.component_based?).to be true
    end
  end

  describe '#batch_generate?' do
    it 'returns true' do
      expect(formatter.batch_generate?).to be true
    end
  end

  describe '#content_type' do
    it 'returns application/zip' do
      expect(formatter.content_type).to eq('application/zip')
    end
  end

  describe '#file_extension' do
    it 'returns -stig-baseline.zip' do
      expect(formatter.file_extension).to eq('-stig-baseline.zip')
    end
  end

  describe '#generate_from_component' do
    let_it_be(:component) { create(:component) }
    let(:ac_rules) do
      component.rules.eager_load(
        :disa_rule_descriptions, :checks, :satisfies, :satisfied_by
      ).order(:rule_id).tap do |rules|
        # Set first rule to AC and generate its inspec_control_file
        rules.first.update_columns(status: status_ac)
        rules.first.update_inspec_code
      end.where(status: status_ac)
         .where.not(id: RuleSatisfaction.select(:rule_id))
    end

    it 'returns a string (zip binary data)' do
      data = formatter.generate_from_component(component: component, rules: ac_rules)
      expect(data).to be_a(String)
    end

    it 'produces a valid zip archive' do
      data = formatter.generate_from_component(component: component, rules: ac_rules)
      io = StringIO.new(data)
      entries = []
      Zip::InputStream.open(io) { |z| entries << z.get_next_entry&.name while z.get_next_entry }
      expect(entries.compact).not_to be_empty
    end

    it 'contains inspec.yml' do
      data = formatter.generate_from_component(component: component, rules: ac_rules)
      entries = zip_entries(data)
      expect(entries).to include(inspec_yml)
    end

    it 'inspec.yml contains all required profile metadata fields' do
      data = formatter.generate_from_component(component: component, rules: ac_rules)
      yml_content = zip_read(data, inspec_yml)
      parsed = YAML.safe_load(yml_content)

      # Fields present in all real MITRE SAF baseline profiles
      expect(parsed['name']).to be_a(String)
      expect(parsed['name']).to eq(component.name.parameterize)
      expect(parsed['title']).to eq(component.title.presence || component.name)
      expect(parsed['maintainer']).to eq(component.admin_name.presence || 'The Authors')
      expect(parsed['copyright']).to be_a(String)
      expect(parsed['copyright']).not_to be_empty
      expect(parsed['license']).to eq('Apache-2.0')
      expect(parsed['summary']).to be_a(String)
      expect(parsed['version']).to match(/\A\d+\.\d+\.\d+\z/) # semver format
      expect(parsed['inspec_version']).to match(/>=/)
    end

    it 'inspec.yml includes copyright_email when admin_email is present' do
      component.update_columns(admin_email: 'test@example.com')
      data = formatter.generate_from_component(component: component.reload, rules: ac_rules)
      yml_content = zip_read(data, inspec_yml)
      parsed = YAML.safe_load(yml_content)
      expect(parsed['copyright_email']).to eq('test@example.com')
    end

    it 'inspec.yml omits copyright_email when admin_email is blank' do
      component.update_columns(admin_email: nil)
      data = formatter.generate_from_component(component: component.reload, rules: ac_rules)
      yml_content = zip_read(data, inspec_yml)
      parsed = YAML.safe_load(yml_content)
      expect(parsed).not_to have_key('copyright_email')
    end

    it 'inspec.yml version derives from component version and release' do
      component.update_columns(version: 3, release: 5)
      data = formatter.generate_from_component(component: component.reload, rules: ac_rules)
      yml_content = zip_read(data, inspec_yml)
      parsed = YAML.safe_load(yml_content)
      expect(parsed['version']).to eq('3.5.0')
    end

    it 'inspec.yml uses standard YAML format (not Ruby symbol keys)' do
      data = formatter.generate_from_component(component: component, rules: ac_rules)
      yml_content = zip_read(data, inspec_yml)
      # Should NOT contain Ruby symbol key format like ":name:"
      expect(yml_content).not_to match(/^:[a-z]/)
      # Should contain standard YAML format like "name:"
      expect(yml_content).to include('name:')
      expect(yml_content).to include('title:')
      expect(yml_content).to include('license:')
    end

    it 'contains control files in controls/ directory' do
      data = formatter.generate_from_component(component: component, rules: ac_rules)
      entries = zip_entries(data)
      control_files = entries.select { |e| e.start_with?('controls/') && e.end_with?('.rb') }
      expect(control_files.size).to eq(ac_rules.count)
    end

    it 'uses component prefix and rule_id for control filename' do
      data = formatter.generate_from_component(component: component, rules: ac_rules)
      rule = ac_rules.first
      expected_name = "controls/#{component.prefix}-#{rule.rule_id}.rb"
      entries = zip_entries(data)
      expect(entries).to include(expected_name)
    end
  end

  describe '#generate_batch' do
    let_it_be(:first_component) { create(:component) }
    let_it_be(:second_component) { create(:component) }
    let(:pairs) do
      [first_component, second_component].map do |c|
        rules = c.rules.eager_load(:disa_rule_descriptions, :checks, :satisfies, :satisfied_by)
                 .where(status: status_ac)
                 .where.not(id: RuleSatisfaction.select(:rule_id))
        { component: c, rules: rules }
      end
    end

    before do
      [first_component, second_component].each do |c|
        c.rules.first.update_columns(status: status_ac)
        c.rules.first.update_inspec_code
      end
    end

    it 'returns zip binary data' do
      data = formatter.generate_batch(component_rule_pairs: pairs)
      expect(data).to be_a(String)
    end

    it 'contains subdirectories for each component' do
      data = formatter.generate_batch(component_rule_pairs: pairs)
      entries = zip_entries(data)

      # Each component should have a subdirectory with inspec.yml
      yml_files = entries.select { |e| e.end_with?(inspec_yml) }
      expect(yml_files.size).to eq(2)
    end

    it 'uses component name in subdirectory path' do
      data = formatter.generate_batch(component_rule_pairs: pairs)
      entries = zip_entries(data)

      version_str = "V#{first_component.version}"
      release_str = "R#{first_component.release}"
      dir = "#{first_component.name.tr(' ', '-')}-#{version_str}#{release_str}-stig-baseline/"

      expect(entries.any? { |e| e.start_with?(dir) }).to be true
    end
  end
end
