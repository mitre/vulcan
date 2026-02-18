# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: JsonArchiveImporter restores a component from a JSON archive
# backup. It validates the manifest, creates components/rules/satisfactions/
# reviews, and supports dry_run mode. Conflict detection prevents duplicates.
#
# Uses test-prof let_it_be for expensive factory setup (SRG XML import).
# Source data is created ONCE per describe block via savepoint transactions.
# ==========================================================================
RSpec.describe Import::JsonArchiveImporter do
  # ------------------------------------------------------------------
  # EXPENSIVE SETUP — created once, shared via savepoint transactions.
  # Each example gets its own savepoint that rolls back after.
  # ------------------------------------------------------------------
  let_it_be(:source_project) { create(:project) }
  let_it_be(:source_component) { create(:component, project: source_project) }
  let_it_be(:second_component) { create(:component, project: source_project) }
  let_it_be(:review_user) { create(:user) }

  # Pre-generate ZIP data once (the expensive export)
  let_it_be(:single_backup_zip) do
    Export::Base.new(
      exportable: source_component,
      mode: :backup,
      format: :json_archive
    ).call.data
  end

  let_it_be(:project_backup_zip) do
    Export::Base.new(
      exportable: source_project,
      mode: :backup,
      format: :json_archive,
      zip_filename: 'test-backup.zip'
    ).call.data
  end

  # Per-example target project (cheap — no SRG import)
  let(:target_project) { create(:project) }

  describe '#call' do
    # ==========================================
    # SINGLE-COMPONENT ARCHIVE
    # ==========================================
    context 'with a valid single-component archive' do
      it 'succeeds' do
        result = import_archive(single_backup_zip, target_project)
        expect(result).to be_success
      end

      it 'creates a component in the target project' do
        expect do
          import_archive(single_backup_zip, target_project)
        end.to change(target_project.components, :count).by(1)
      end

      it 'preserves component name' do
        import_archive(single_backup_zip, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        expect(imported).to be_present
      end

      it 'preserves component attributes' do
        import_archive(single_backup_zip, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        expect(imported.prefix).to eq(source_component.prefix)
        expect(imported.version).to eq(source_component.version)
        expect(imported.release).to eq(source_component.release)
        expect(imported.title).to eq(source_component.title)
      end

      it 'creates all rules' do
        import_archive(single_backup_zip, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        expect(imported.rules.count).to eq(source_component.rules.count)
      end

      it 'preserves rule attributes' do
        import_archive(single_backup_zip, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        original_rule = source_component.rules.order(:rule_id).first
        imported_rule = imported.rules.order(:rule_id).first

        expect(imported_rule.rule_id).to eq(original_rule.rule_id)
        expect(imported_rule.status).to eq(original_rule.status)
        expect(imported_rule.title).to eq(original_rule.title)
      end

      it 'preserves disa_rule_descriptions' do
        import_archive(single_backup_zip, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        imported_rule = imported.rules.order(:rule_id).first
        original_rule = source_component.rules.order(:rule_id).first

        expect(imported_rule.disa_rule_descriptions.size).to eq(original_rule.disa_rule_descriptions.size)
      end

      it 'preserves checks' do
        import_archive(single_backup_zip, target_project)
        imported = target_project.components.find_by(name: source_component.name)
        imported_rule = imported.rules.order(:rule_id).first
        original_rule = source_component.rules.order(:rule_id).first

        expect(imported_rule.checks.size).to eq(original_rule.checks.size)
      end

      it 'returns summary with counts' do
        result = import_archive(single_backup_zip, target_project)
        expect(result.summary[:components_imported]).to eq(1)
        expect(result.summary[:rules_imported]).to eq(source_component.rules.count)
      end
    end

    # ==========================================
    # SATISFACTIONS
    # ==========================================
    context 'with satisfactions' do
      # Need fresh ZIP with satisfactions baked in
      let(:zip_with_sats) do
        rules = source_component.rules.order(:rule_id).to_a
        RuleSatisfaction.find_or_create_by!(rule_id: rules[1].id, satisfied_by_rule_id: rules[0].id)
        Export::Base.new(
          exportable: source_component,
          mode: :backup,
          format: :json_archive
        ).call.data
      end

      it 'rebuilds satisfaction relationships' do
        result = import_archive(zip_with_sats, target_project)
        expect(result).to be_success

        imported = target_project.components.find_by(name: source_component.name)
        imported_rules = imported.rules.order(:rule_id).to_a
        expect(imported_rules[1].satisfied_by).to include(imported_rules[0])
      end

      it 'reports satisfaction count in summary' do
        result = import_archive(zip_with_sats, target_project)
        expect(result.summary[:satisfactions_imported]).to eq(1)
      end
    end

    # ==========================================
    # REVIEWS
    # ==========================================
    context 'with reviews' do
      let(:zip_with_reviews) do
        rule = source_component.rules.first
        Review.find_or_create_by!(user: review_user, rule: rule, action: 'request_review') do |r|
          r.comment = 'Review this'
        end
        Export::Base.new(
          exportable: source_component,
          mode: :backup,
          format: :json_archive
        ).call.data
      end

      it 'imports reviews when include_reviews is true' do
        result = import_archive(zip_with_reviews, target_project, include_reviews: true)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to eq(1)
      end

      it 'skips reviews when include_reviews is false' do
        result = import_archive(zip_with_reviews, target_project, include_reviews: false)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to eq(0)
      end
    end

    context 'with review user resolved by name fallback' do
      let(:named_user) { create(:user, name: 'Jane Reviewer') }

      let(:zip_with_named_review) do
        Membership.create!(user: named_user, membership: source_project, role: 'admin')
        rule = source_component.rules.first
        Review.create!(user: named_user, rule: rule, action: 'lock_control', comment: 'Locking')
        Export::Base.new(
          exportable: source_component,
          mode: :backup,
          format: :json_archive
        ).call.data
      end

      it 'resolves review user by email (primary path)' do
        result = import_archive(zip_with_named_review, target_project, include_reviews: true)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to be >= 1
      end
    end

    context 'with unresolvable review user' do
      it 'skips review and adds warning when user cannot be found' do
        ghost_user = create(:user, email: 'ghost@example.com', name: 'Ghost')
        Membership.create!(user: ghost_user, membership: source_project, role: 'admin')
        rule = source_component.rules.first
        Review.create!(user: ghost_user, rule: rule, action: 'lock_control', comment: 'Haunted')

        zip = Export::Base.new(
          exportable: source_component,
          mode: :backup,
          format: :json_archive
        ).call.data

        ghost_user.reviews.delete_all
        ghost_user.destroy!

        result = import_archive(zip, target_project, include_reviews: true)
        expect(result).to be_success
        expect(result.summary[:reviews_imported]).to eq(0)
        expect(result.warnings).to include(a_string_matching(/ghost@example\.com.*not found/))
      end
    end

    # ==========================================
    # DRY RUN
    # ==========================================
    context 'with dry_run mode' do
      it 'succeeds' do
        result = import_archive(single_backup_zip, target_project, dry_run: true)
        expect(result).to be_success
      end

      it 'creates no records' do
        expect do
          import_archive(single_backup_zip, target_project, dry_run: true)
        end.not_to change(Component, :count)
      end

      it 'marks summary as dry_run' do
        result = import_archive(single_backup_zip, target_project, dry_run: true)
        expect(result.summary[:dry_run]).to be true
      end
    end

    # ==========================================
    # INVALID ARCHIVES
    # ==========================================
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

    # ==========================================
    # MEMBERSHIPS
    # ==========================================
    context 'with memberships' do
      let(:member_user) { create(:user) }

      let(:zip_with_memberships) do
        Membership.find_or_create_by!(user: member_user, membership: source_project, role: 'author')
        Export::Base.new(
          exportable: source_project,
          mode: :backup,
          format: :json_archive,
          zip_filename: 'test-backup.zip'
        ).call.data
      end

      it 'imports memberships when include_memberships is true' do
        result = import_archive(zip_with_memberships, target_project, include_memberships: true)
        expect(result).to be_success
        expect(result.summary[:memberships_imported]).to eq(1)
      end

      it 'skips memberships when include_memberships is false (default)' do
        result = import_archive(zip_with_memberships, target_project)
        expect(result).to be_success
        expect(result.summary[:memberships_imported]).to eq(0)
      end

      it 'reports memberships_imported in summary' do
        result = import_archive(zip_with_memberships, target_project, include_memberships: true)
        expect(result.summary).to have_key(:memberships_imported)
      end
    end

    # ==========================================
    # MISSING OPTIONAL ENTRIES
    # ==========================================
    context 'with missing optional ZIP entries' do
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

    # ==========================================
    # NAME CONFLICTS
    # ==========================================
    context 'with component name conflict' do
      before do
        create(:component,
               project: target_project,
               name: source_component.name,
               based_on: source_component.based_on)
      end

      it 'fails with conflict error' do
        result = import_archive(single_backup_zip, target_project)
        expect(result).not_to be_success
        expect(result.errors.first).to match(/already exists/)
      end
    end

    context 'with missing SRG' do
      it 'fails when required SRG is not in the system' do
        modified_zip = modify_manifest_srg(single_backup_zip, 'NONEXISTENT-SRG-ID-12345')
        result = import_archive(modified_zip, target_project)
        expect(result).not_to be_success
        expect(result.errors.first).to match(/Required SRG not found/)
      end
    end

    # ==========================================
    # MULTI-COMPONENT
    # ==========================================
    context 'with multi-component project backup' do
      it 'imports all components' do
        result = import_archive(project_backup_zip, target_project)
        expect(result).to be_success
        expect(result.summary[:components_imported]).to eq(2)
      end

      it 'creates both components in target project' do
        expect do
          import_archive(project_backup_zip, target_project)
        end.to change(target_project.components, :count).by(2)
      end
    end

    # ==========================================
    # COMPONENT FILTER
    # ==========================================
    context 'with component_filter' do
      it 'imports only filtered components' do
        filter = { source_component.name => source_component.name }
        result = import_archive(project_backup_zip, target_project, component_filter: filter)
        expect(result).to be_success
        expect(result.summary[:components_imported]).to eq(1)
        expect(target_project.components.pluck(:name)).to contain_exactly(source_component.name)
      end

      it 'imports all when component_filter is nil' do
        result = import_archive(project_backup_zip, target_project, component_filter: nil)
        expect(result).to be_success
        expect(result.summary[:components_imported]).to eq(2)
      end

      it 'renames component when filter maps to different name' do
        new_name = "#{source_component.name} (restored)"
        filter = { source_component.name => new_name }
        result = import_archive(project_backup_zip, target_project, component_filter: filter)
        expect(result).to be_success
        expect(target_project.components.find_by(name: new_name)).to be_present
      end

      it 'skips components not in filter keys' do
        filter = { second_component.name => second_component.name }
        result = import_archive(project_backup_zip, target_project, component_filter: filter)
        expect(result).to be_success
        expect(target_project.components.pluck(:name)).to contain_exactly(second_component.name)
      end
    end

    # ==========================================
    # COMPONENT DETAILS
    # ==========================================
    context 'with component_details in summary' do
      it 'includes component_details in dry_run summary' do
        result = import_archive(project_backup_zip, target_project, dry_run: true)
        expect(result.summary[:component_details]).to be_an(Array)
        expect(result.summary[:component_details].size).to eq(2)
      end

      it 'reports name and rule_count per component' do
        result = import_archive(project_backup_zip, target_project, dry_run: true)
        detail = result.summary[:component_details].find { |d| d[:name] == source_component.name }
        expect(detail).to be_present
        expect(detail[:rule_count]).to eq(source_component.rules.count)
      end

      it 'detects conflicts with existing components' do
        create(:component,
               project: target_project,
               name: source_component.name,
               based_on: source_component.based_on)

        filter = { second_component.name => second_component.name }
        result = import_archive(project_backup_zip, target_project,
                                dry_run: true, component_filter: filter)
        expect(result).to be_success
        detail = result.summary[:component_details].find { |d| d[:name] == source_component.name }
        expect(detail[:conflict]).to be true
      end

      it 'allows importing conflicting component with renamed name via filter' do
        create(:component,
               project: target_project,
               name: source_component.name,
               based_on: source_component.based_on)

        new_name = "#{source_component.name} (restored)"
        filter = {
          source_component.name => new_name,
          second_component.name => second_component.name
        }
        result = import_archive(project_backup_zip, target_project, component_filter: filter)
        expect(result).to be_success
        expect(target_project.components.find_by(name: new_name)).to be_present
      end
    end

    # ==========================================
    # CONFLICT + FILTER INTERACTION
    # ==========================================
    context 'with component name conflict and component_filter' do
      before do
        create(:component,
               project: target_project,
               name: source_component.name,
               based_on: source_component.based_on)
      end

      it 'treats conflicts as warnings (not errors) when component_filter is provided' do
        filter = {}
        result = import_archive(single_backup_zip, target_project, component_filter: filter)
        expect(result).to be_success
      end
    end
  end

  private

  def import_archive(zip_data, proj, dry_run: false, include_reviews: true, include_memberships: false,
                     component_filter: nil)
    Import::JsonArchiveImporter.new(
      zip_file: zip_data,
      project: proj,
      dry_run: dry_run,
      include_reviews: include_reviews,
      include_memberships: include_memberships,
      component_filter: component_filter
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
