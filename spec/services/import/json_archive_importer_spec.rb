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

    # PR #717 — public-comment review workflow must survive backup/restore.
    # Without this, a backup taken mid-review would lose
    # all triage decisions, adjudication metadata, reply threading, and
    # comment-phase state on restore.
    context 'with PR-717 public-comment review lifecycle data' do
      let_it_be(:lifecycle_project) { create(:project) }
      let_it_be(:lifecycle_component) do
        create(:component,
               project: lifecycle_project,
               comment_phase: 'open',
               comment_period_starts_at: '2026-04-15T00:00:00Z',
               comment_period_ends_at: '2026-04-30T00:00:00Z')
      end
      let_it_be(:lifecycle_commenter) { create(:user, name: 'Lifecycle Commenter') }
      let_it_be(:lifecycle_triager) { create(:user, name: 'Lifecycle Triager') }

      let_it_be(:lifecycle_top_review) do
        Membership.find_or_create_by!(
          user: lifecycle_commenter, membership: lifecycle_project
        ) { |m| m.role = 'viewer' }
        Membership.find_or_create_by!(
          user: lifecycle_triager, membership: lifecycle_project
        ) { |m| m.role = 'author' }
        Review.create!(
          user: lifecycle_commenter, rule: lifecycle_component.rules.first,
          action: 'comment', comment: 'TLS 1.2 EOL',
          section: 'check_content',
          triage_status: 'concur_with_comment',
          triage_set_by: lifecycle_triager, triage_set_at: 1.day.ago,
          adjudicated_at: 12.hours.ago, adjudicated_by: lifecycle_triager
        )
      end
      let_it_be(:lifecycle_reply) do
        Review.create!(
          user: lifecycle_triager, rule: lifecycle_component.rules.first,
          action: 'comment', comment: 'will fix in next revision',
          responding_to_review_id: lifecycle_top_review.id
        )
      end
      let_it_be(:lifecycle_dup_target) do
        Review.create!(
          user: lifecycle_commenter, rule: lifecycle_component.rules.second,
          action: 'comment', comment: 'duplicate target'
        )
      end
      let_it_be(:lifecycle_dup) do
        Review.create!(
          user: lifecycle_commenter, rule: lifecycle_component.rules.second,
          action: 'comment', comment: 'duplicate source',
          duplicate_of_review_id: lifecycle_dup_target.id,
          triage_status: 'duplicate'
        )
      end

      let_it_be(:lifecycle_zip) do
        Export::Base.new(
          exportable: lifecycle_component, mode: :backup, format: :json_archive
        ).call.data
      end

      let(:lifecycle_target_project) { create(:project) }

      it 'restores comment_phase + comment_period_*' do
        import_archive(lifecycle_zip, lifecycle_target_project)
        imported = lifecycle_target_project.components.find_by(name: lifecycle_component.name)
        expect(imported.comment_phase).to eq('open')
        expect(imported.comment_period_starts_at).to be_present
        expect(imported.comment_period_ends_at).to be_present
      end

      it 'restores triage_status + section on each comment' do
        import_archive(lifecycle_zip, lifecycle_target_project)
        imported = lifecycle_target_project.components.find_by(name: lifecycle_component.name)
        top = imported.rules.flat_map(&:reviews).find { |r| r.comment == 'TLS 1.2 EOL' }
        expect(top.triage_status).to eq('concur_with_comment')
        expect(top.section).to eq('check_content')
      end

      it 'restores triage_set_by + adjudicated_by user references via email' do
        import_archive(lifecycle_zip, lifecycle_target_project)
        imported = lifecycle_target_project.components.find_by(name: lifecycle_component.name)
        top = imported.rules.flat_map(&:reviews).find { |r| r.comment == 'TLS 1.2 EOL' }
        expect(top.triage_set_by_id).to eq(lifecycle_triager.id)
        expect(top.adjudicated_by_id).to eq(lifecycle_triager.id)
        expect(top.triage_set_at).to be_present
        expect(top.adjudicated_at).to be_present
      end

      it 'rebuilds reply threading (responding_to_review_id) using the new ids' do
        import_archive(lifecycle_zip, lifecycle_target_project)
        imported = lifecycle_target_project.components.find_by(name: lifecycle_component.name)
        all_reviews = imported.rules.flat_map(&:reviews)
        parent = all_reviews.find { |r| r.comment == 'TLS 1.2 EOL' }
        reply  = all_reviews.find { |r| r.comment == 'will fix in next revision' }
        expect(reply.responding_to_review_id).to eq(parent.id)
      end

      it 'rebuilds duplicate_of cross-link using the new ids' do
        import_archive(lifecycle_zip, lifecycle_target_project)
        imported = lifecycle_target_project.components.find_by(name: lifecycle_component.name)
        all_reviews = imported.rules.flat_map(&:reviews)
        target = all_reviews.find { |r| r.comment == 'duplicate target' }
        dup    = all_reviews.find { |r| r.comment == 'duplicate source' }
        expect(dup.duplicate_of_review_id).to eq(target.id)
        expect(dup.triage_status).to eq('duplicate')
      end

      # PR-717 review remediation .10 — Component-level import audit row.
      # Reconstructs WHICH external_ids landed FROM WHICH archive so an
      # admin_destroy → re-import roundtrip leaves a recovery trail.
      it 'writes a Component import_reviews audit row with external_ids and archive identifier' do
        import_archive(lifecycle_zip, lifecycle_target_project)
        imported = lifecycle_target_project.components.find_by(name: lifecycle_component.name)
        audit = imported.audits.find_by(action: 'import_reviews')
        expect(audit).to be_present
        expect(audit.audited_changes['review_external_ids']).to be_an(Array)
        expect(audit.audited_changes['review_external_ids']).not_to be_empty
        expect(audit.audited_changes['archive_vulcan_version']).to be_present
        expect(audit.audited_changes['archive_exported_at']).to be_present
        expect(audit.comment).to match(/Imported \d+ reviews from backup archive/)
      end

      # PR-717 review remediation .8 — preserve original attribution
      # per-review when the User can't be resolved on import. Researched
      # GitLab's placeholder-user pattern (overkill for one-shot
      # backup/restore use case); 4 cols on Review carry the email + name
      # forward and display/export layers fall back to them.
      # https://docs.gitlab.com/development/user_contribution_mapping/
      #
      # let_it_be uses refind: true on orphan_triager so destroy! gets a
      # fresh AR instance per example (otherwise the cached Ruby object
      # retains @destroyed=true after savepoint rollback and the audited
      # gem's after_destroy fires "create unless parent is saved").
      # https://github.com/test-prof/test-prof/blob/master/docs/recipes/let_it_be.md
      context 'when triage_set_by/adjudicated_by user is missing on the target' do # rubocop:disable RSpec/NestedGroups
        let_it_be(:orphan_proj) { create(:project) }
        let_it_be(:orphan_component) { create(:component, project: orphan_proj) }
        let_it_be(:orphan_commenter) { create(:user, name: 'Orphan Commenter') }
        let_it_be(:orphan_triager, refind: true) do
          create(:user, name: 'Orphan Triager', email: 'orphan-triager@example.com')
        end
        let_it_be(:orphan_review) do
          Membership.find_or_create_by!(user: orphan_commenter, membership: orphan_proj) { |m| m.role = 'viewer' }
          Membership.find_or_create_by!(user: orphan_triager, membership: orphan_proj) { |m| m.role = 'author' }
          Review.create!(
            user: orphan_commenter, rule: orphan_component.rules.first,
            action: 'comment', comment: 'orphan-test comment',
            triage_status: 'concur',
            triage_set_by: orphan_triager, triage_set_at: 1.day.ago,
            adjudicated_at: 12.hours.ago, adjudicated_by: orphan_triager
          )
        end
        let_it_be(:orphan_zip) do
          Export::Base.new(
            exportable: orphan_component, mode: :backup, format: :json_archive
          ).call.data
        end

        before do
          # Wipe the triager so the import-side User.find_by(email:) returns nil.
          # FK satisfaction first, then the User. refind: true above gives
          # us a fresh AR instance per example so destroy! works repeatedly
          # across the savepoint-rollback boundary.
          Membership.where(user: orphan_triager).destroy_all
          orphan_triager.destroy!
        end

        let(:orphan_target_project) { create(:project) }

        it 'records a warning naming the missing email' do
          result = import_archive(orphan_zip, orphan_target_project)
          expect(result.warnings).to include(a_string_matching(/triage_set_by.*orphan-triager@example.com/i))
        end

        it 'imports the review with FK nil but imported_email + imported_name populated' do
          import_archive(orphan_zip, orphan_target_project)
          imported = orphan_target_project.components.find_by(name: orphan_component.name)
          rev = imported.rules.flat_map(&:reviews).find { |r| r.comment == 'orphan-test comment' }
          expect(rev).to be_present
          expect(rev.triage_set_by_id).to be_nil
          expect(rev.triage_set_by_imported_email).to eq('orphan-triager@example.com')
          expect(rev.triage_set_by_imported_name).to eq('Orphan Triager')
          expect(rev.adjudicated_by_id).to be_nil
          expect(rev.adjudicated_by_imported_email).to eq('orphan-triager@example.com')
          expect(rev.adjudicated_by_imported_name).to eq('Orphan Triager')
        end

        it 'leaves imported_* nil when the user resolves successfully' do
          # Re-create the triager BEFORE import so resolution succeeds.
          create(:user, name: 'Orphan Triager Restored', email: 'orphan-triager@example.com')
          import_archive(orphan_zip, orphan_target_project)
          imported = orphan_target_project.components.find_by(name: orphan_component.name)
          rev = imported.rules.flat_map(&:reviews).find { |r| r.comment == 'orphan-test comment' }
          expect(rev.triage_set_by_id).to be_present
          expect(rev.triage_set_by_imported_email).to be_nil
          expect(rev.triage_set_by_imported_name).to be_nil
        end

        it 'does not warn when triage_set_by_email is absent from the archive' do
          plain_proj = create(:project)
          plain_component = create(:component, project: plain_proj)
          plain_commenter = create(:user, name: 'Plain Commenter')
          Membership.find_or_create_by!(user: plain_commenter, membership: plain_proj) { |m| m.role = 'viewer' }
          Review.create!(
            user: plain_commenter, rule: plain_component.rules.first,
            action: 'comment', comment: 'plain comment without triage'
          )
          plain_zip = Export::Base.new(
            exportable: plain_component, mode: :backup, format: :json_archive
          ).call.data
          plain_target = create(:project)
          result = import_archive(plain_zip, plain_target)
          expect(result.warnings).not_to include(a_string_matching(/triage_set_by/i))
          expect(result.warnings).not_to include(a_string_matching(/adjudicated_by/i))
        end
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
