# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: JsonArchiveImporter restores a component from a JSON archive
# backup. It validates the manifest, creates components/rules/satisfactions/
# reviews, and supports dry_run mode. Conflict detection prevents duplicates.
# ==========================================================================
RSpec.describe Import::JsonArchiveImporter do
  let(:project) { create(:project) }
  let(:source_component) { create(:component, project: project) }
  let(:target_project) { create(:project) }
  let(:user) { create(:user) }

  # Generate a backup archive from the source component
  let(:backup_zip_data) do
    Export::Base.new(
      exportable: source_component,
      mode: :backup,
      format: :json_archive
    ).call.data
  end

  describe '#call' do
    context 'with a valid single-component archive' do
      it 'succeeds' do
        result = import_archive(backup_zip_data, target_project)
        expect(result).to be_success
      end

      it 'creates a component in the target project' do
        expect do
          import_archive(backup_zip_data, target_project)
        end.to change(target_project.components, :count).by(1)
      end

      it 'preserves component name' do
        import_archive(backup_zip_data, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        expect(imported).to be_present
      end

      it 'preserves component attributes' do
        import_archive(backup_zip_data, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        expect(imported.prefix).to eq(source_component.prefix)
        expect(imported.version).to eq(source_component.version)
        expect(imported.release).to eq(source_component.release)
        expect(imported.title).to eq(source_component.title)
      end

      it 'creates all rules' do
        import_archive(backup_zip_data, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        expect(imported.rules.count).to eq(source_component.rules.count)
      end

      it 'preserves rule attributes' do
        import_archive(backup_zip_data, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        original_rule = source_component.rules.order(:rule_id).first
        imported_rule = imported.rules.order(:rule_id).first

        expect(imported_rule.rule_id).to eq(original_rule.rule_id)
        expect(imported_rule.status).to eq(original_rule.status)
        expect(imported_rule.title).to eq(original_rule.title)
      end

      it 'preserves disa_rule_descriptions' do
        import_archive(backup_zip_data, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        imported_rule = imported.rules.order(:rule_id).first
        original_rule = source_component.rules.order(:rule_id).first

        expect(imported_rule.disa_rule_descriptions.size).to eq(original_rule.disa_rule_descriptions.size)
      end

      it 'preserves checks' do
        import_archive(backup_zip_data, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        imported_rule = imported.rules.order(:rule_id).first
        original_rule = source_component.rules.order(:rule_id).first

        expect(imported_rule.checks.size).to eq(original_rule.checks.size)
      end

      it 'returns summary with counts' do
        result = import_archive(backup_zip_data, target_project)
        expect(result.summary[:components_imported]).to eq(1)
        expect(result.summary[:rules_imported]).to eq(source_component.rules.count)
      end
    end

    context 'with satisfactions' do
      let(:rules) { source_component.rules.order(:rule_id).to_a }

      before do
        RuleSatisfaction.create!(rule_id: rules[1].id, satisfied_by_rule_id: rules[0].id)
      end

      it 'rebuilds satisfaction relationships' do
        result = import_archive(backup_zip_data, target_project)
        expect(result).to be_success

        imported = target_project.components.find_by(name: source_component.name)
        imported_rules = imported.rules.order(:rule_id).to_a

        # Verify the satisfaction was recreated
        expect(imported_rules[1].satisfied_by).to include(imported_rules[0])
      end

      it 'reports satisfaction count in summary' do
        result = import_archive(backup_zip_data, target_project)
        expect(result.summary[:satisfactions_imported]).to eq(1)
      end
    end

    context 'with reviews' do
      before do
        rule = source_component.rules.first
        Review.create!(user: user, rule: rule, action: 'request_review', comment: 'Review this')
      end

      it 'imports reviews when include_reviews is true' do
        result = import_archive(backup_zip_data, target_project, include_reviews: true)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to eq(1)
      end

      it 'skips reviews when include_reviews is false' do
        result = import_archive(backup_zip_data, target_project, include_reviews: false)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to eq(0)
      end
    end

    context 'with review user resolved by name fallback' do
      let(:named_user) { create(:user, name: 'Jane Reviewer') }

      before do
        # lock_control requires admin membership and unlocked control
        Membership.create!(user: named_user, membership: project, role: 'admin')
        rule = source_component.rules.first
        Review.create!(user: named_user, rule: rule, action: 'lock_control', comment: 'Locking for review')
      end

      it 'resolves review user by email (primary path)' do
        result = import_archive(backup_zip_data, target_project, include_reviews: true)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to eq(1)
      end
    end

    context 'with unresolvable review user' do
      it 'skips review and adds warning when user cannot be found' do
        ghost_user = create(:user, email: 'ghost@example.com', name: 'Ghost')
        Membership.create!(user: ghost_user, membership: project, role: 'admin')
        rule = source_component.rules.first
        Review.create!(user: ghost_user, rule: rule, action: 'lock_control', comment: 'Haunted review')

        zip = backup_zip_data
        # Delete the user so it can't be resolved on import
        ghost_user.reviews.delete_all
        ghost_user.destroy!

        result = import_archive(zip, target_project, include_reviews: true)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to eq(0)
        expect(result.warnings).to include(a_string_matching(/ghost@example\.com.*not found/))
      end
    end

    context 'with dry_run mode' do
      before { backup_zip_data } # Force eager evaluation so source_component doesn't inflate counts

      it 'succeeds' do
        result = import_archive(backup_zip_data, target_project, dry_run: true)
        expect(result).to be_success
      end

      it 'creates no records' do
        expect do
          import_archive(backup_zip_data, target_project, dry_run: true)
        end.not_to change(Component, :count)
      end

      it 'marks summary as dry_run' do
        result = import_archive(backup_zip_data, target_project, dry_run: true)
        expect(result.summary[:dry_run]).to be true
      end
    end

    context 'with invalid archive' do
      it 'fails with invalid ZIP' do
        result = import_archive('not a zip file', target_project)
        expect(result).not_to be_success
        expect(result.errors.first).to match(/Invalid ZIP file/)
      end

      it 'fails when manifest.json is missing' do
        zip_data = Zip::OutputStream.write_buffer do |zio|
          zio.put_next_entry('component.json')
          zio.write('{}')
        end.string

        result = import_archive(zip_data, target_project)
        expect(result).not_to be_success
        expect(result.errors.first).to match(/manifest.json not found/)
      end

      it 'fails with malformed JSON in manifest' do
        zip_data = Zip::OutputStream.write_buffer do |zio|
          zio.put_next_entry('manifest.json')
          zio.write('{ not valid json }')
        end.string

        result = import_archive(zip_data, target_project)
        expect(result).not_to be_success
        expect(result.errors.first).to match(/Invalid JSON/)
      end
    end

    context 'with missing optional ZIP entries' do
      # The importer defaults to [] when rules.json, satisfactions.json,
      # or reviews.json are absent. This tests that behavior.
      let(:minimal_zip) do
        srg = SecurityRequirementsGuide.find(source_component.security_requirements_guide_id)
        manifest = {
          'backup_format_version' => '1.0',
          'exported_at' => Time.current.iso8601,
          'components' => [{
            'name' => 'Minimal Component',
            'srg_id' => srg.srg_id,
            'srg_version' => srg.version
          }]
        }
        component_data = {
          'name' => 'Minimal Component',
          'prefix' => 'MMMM-00',
          'version' => 1,
          'release' => 1,
          'title' => 'Minimal',
          'based_on' => { 'srg_id' => srg.srg_id, 'version' => srg.version }
        }

        Zip::OutputStream.write_buffer do |zio|
          zio.put_next_entry('manifest.json')
          zio.write(JSON.generate(manifest))
          zio.put_next_entry('component.json')
          zio.write(JSON.generate(component_data))
          # Intentionally omit: rules.json, satisfactions.json, reviews.json
        end.string
      end

      it 'succeeds with only manifest and component (no rules/satisfactions/reviews files)' do
        result = import_archive(minimal_zip, target_project)
        expect(result).to be_success
        expect(result.summary[:rules_imported]).to eq(0)
        expect(result.summary[:satisfactions_imported]).to eq(0)
        expect(result.summary[:reviews_imported]).to eq(0)
      end
    end

    context 'with component name conflict' do
      before do
        # Create a component with the same name in the target project
        create(:component,
               project: target_project,
               name: source_component.name,
               based_on: source_component.based_on)
      end

      it 'fails with conflict error' do
        result = import_archive(backup_zip_data, target_project)
        expect(result).not_to be_success
        expect(result.errors.first).to match(/already exists/)
      end
    end

    context 'with missing SRG' do
      it 'fails when required SRG is not in the system' do
        # Destroy the SRG after export but before import
        srg = source_component.based_on
        srg.srg_id

        # We need to build the zip BEFORE destroying the SRG
        zip = backup_zip_data

        # Now destroy the SRG (and detach from component to avoid FK issues)
        # Since we can't easily destroy the SRG with existing components,
        # we modify the manifest to reference a non-existent SRG
        modified_zip = modify_manifest_srg(zip, 'NONEXISTENT-SRG-ID-12345')

        result = import_archive(modified_zip, target_project)
        expect(result).not_to be_success
        expect(result.errors.first).to match(/Required SRG not found/)
      end
    end

    context 'with multi-component project backup' do
      let(:second_component) { create(:component, project: project) }

      let(:project_backup_zip_data) do
        Export::Base.new(
          exportable: project,
          mode: :backup,
          format: :json_archive,
          zip_filename: 'test-backup.zip'
        ).call.data
      end

      before do
        # Ensure both components exist before export
        source_component
        second_component
      end

      it 'imports all components' do
        result = import_archive(project_backup_zip_data, target_project)
        expect(result).to be_success
        expect(result.summary[:components_imported]).to eq(2)
      end

      it 'creates both components in target project' do
        expect do
          import_archive(project_backup_zip_data, target_project)
        end.to change(target_project.components, :count).by(2)
      end
    end
  end

  private

  def import_archive(zip_data, proj, dry_run: false, include_reviews: true)
    Import::JsonArchiveImporter.new(
      zip_file: zip_data,
      project: proj,
      dry_run: dry_run,
      include_reviews: include_reviews
    ).call
  end

  def modify_manifest_srg(zip_data, new_srg_id)
    new_zip = Zip::OutputStream.write_buffer do |zio|
      Zip::File.open_buffer(StringIO.new(zip_data)) do |zip|
        zip.each do |entry|
          zio.put_next_entry(entry.name)
          if entry.name == 'manifest.json'
            manifest = JSON.parse(zip.read(entry.name))
            manifest['components'].each { |c| c['srg_id'] = new_srg_id }
            zio.write(JSON.generate(manifest))
          elsif entry.name == 'component.json'
            component_data = JSON.parse(zip.read(entry.name))
            component_data['based_on']['srg_id'] = new_srg_id
            zio.write(JSON.generate(component_data))
          else
            zio.write(zip.read(entry.name))
          end
        end
      end
    end
    new_zip.string
  end
end
