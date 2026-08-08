# frozen_string_literal: true

require 'rails_helper'

# ===========================================================================
# REQUIREMENT: an SRG-kind component's backup archive must contain its
# authored SrgRules, reviews, and comments — not an empty rules list — and
# the restore path must rebuild authored SrgRules (not Rules), re-linking
# derived_from by catalog version. Without this, the pre-delete backup is
# silently void for SRG components: deleting one would be unrecoverable.
# ===========================================================================
RSpec.describe 'SRG-kind JSON Archive Backup Round-Trip' do
  let_it_be(:source_project) { create(:project, name: 'SRG Source Project') }
  let_it_be(:admin) { create(:user, admin: true) }
  let_it_be(:membership) { Membership.create!(user: admin, membership: source_project, role: 'admin') }
  let_it_be(:source_component) do
    create(:component, :skip_rules, project: source_project, document_type: 'srg',
                                    prefix: 'SRGB-00', name: 'SRG Backup Test', title: 'SRG Backup Test')
  end
  # Bypass the id-less based_on select scope
  let_it_be(:catalog_srg) { SecurityRequirementsGuide.find(source_component.security_requirements_guide_id) }
  let_it_be(:catalog_rule) { catalog_srg.srg_rules.order(:id).first }
  let_it_be(:authored_one) do
    create(:srg_rule, :authored, component: source_component, rule_id: '000001',
                                 status: 'Applicable', derived_from_srg_rule_id: catalog_rule.id,
                                 title: 'First authored requirement', fixtext: 'Do the secure thing.')
  end
  let_it_be(:authored_two) do
    create(:srg_rule, :authored, component: source_component, rule_id: '000002',
                                 status: 'Not Applicable', title: 'Second authored requirement',
                                 status_justification: 'Decided out of scope')
  end
  let_it_be(:srg_comment) do
    create(:review, :comment, user: admin, rule: nil, commentable: authored_one,
                              comment: 'Round-trip comment on an authored requirement', section: 'fixtext')
  end

  let_it_be(:source_backup_zip) do
    Export::Base.new(
      exportable: source_component.reload,
      mode: :backup,
      format: :json_archive
    ).call.data
  end

  # Read the component.json out of an archive.
  def component_json_from(zip_data)
    Zip::File.open_buffer(zip_data) do |zip|
      entry = zip.find { |e| e.name.end_with?('component.json') }
      return JSON.parse(entry.get_input_stream.read)
    end
  end

  # Rebuild an archive with component.json altered by the block. Used to
  # synthesize archives this code path must tolerate but cannot produce —
  # an older format, or a source the destination catalog does not carry.
  def rewrite_component_json(zip_data)
    Zip::OutputStream.write_buffer do |out|
      Zip::File.open_buffer(zip_data) do |zip|
        zip.each do |entry|
          body = entry.get_input_stream.read
          if entry.name.end_with?('component.json')
            parsed = JSON.parse(body)
            yield parsed
            body = parsed.to_json
          end
          out.put_next_entry(entry.name)
          out.write(body)
        end
      end
    end.string
  end

  let(:target_project) { create(:project, name: 'SRG Target Project') }
  let(:import_result) do
    Import::JsonArchiveImporter.new(
      zip_file: source_backup_zip,
      project: target_project,
      include_reviews: true
    ).call
  end
  let(:imported_component) { target_project.components.find_by(name: 'SRG Backup Test') }

  describe 'the archive contents' do
    let(:archive_entries) do
      entries = {}
      Zip::File.open_buffer(source_backup_zip) do |zip|
        zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
      end
      entries
    end

    it 'contains the authored requirements, document_type, and the comment — not an empty archive' do
      component_json = JSON.parse(archive_entries.find { |name, _| name.end_with?('component.json') }.last)
      rules_json = JSON.parse(archive_entries.find { |name, _| name.end_with?('rules.json') }.last)
      reviews_json = JSON.parse(archive_entries.find { |name, _| name.end_with?('reviews.json') }.last)

      expect(component_json['document_type']).to eq('srg')
      expect(rules_json.pluck('rule_id')).to contain_exactly('000001', '000002')
      expect(rules_json.find { |r| r['rule_id'] == '000001' }['derived_from_srg_rule_version'])
        .to eq(catalog_rule.version)
      expect(reviews_json.pluck('comment'))
        .to include('Round-trip comment on an authored requirement')
    end

    # A single-parent component is the common case and must not change shape:
    # exactly one source, matching based_on, and no leaked database ids.
    it 'carries exactly one source SRG for a single-parent component, matching based_on' do
      component_json = JSON.parse(archive_entries.find { |name, _| name.end_with?('component.json') }.last)

      expect(component_json['source_srgs'].length).to eq(1)
      expect(component_json['source_srgs'].first)
        .to eq('srg_id' => catalog_srg.srg_id, 'title' => catalog_srg.title, 'version' => catalog_srg.version)
      expect(component_json['based_on']['srg_id']).to eq(catalog_srg.srg_id)
    end
  end

  # A component may derive from more than one core SRG. The backup carried
  # only the singular based_on, so a secondary source was silently absent
  # from the archive and gone after restore — the archive itself was
  # incomplete, so no later restore could recover it.
  describe 'a component with more than one source SRG' do
    # srg_id deliberately sorts BEFORE the factory-sequenced catalog SRG so
    # insertion order differs from sorted order — otherwise the sort-order
    # assertion below passes even without sorting.
    let_it_be(:secondary_srg) do
      create(:security_requirements_guide, :core, :skip_rules, srg_id: 'SRG-AAAA-SECONDARY')
    end
    let_it_be(:multi_source_component) do
      component = create(:component, :skip_rules, project: source_project, document_type: 'srg',
                                                  prefix: 'SRGM-00', name: 'SRG Multi Source',
                                                  title: 'SRG Multi Source')
      component.add_source_parent!(secondary_srg)
      component.reload
    end
    let_it_be(:multi_source_zip) do
      Export::Base.new(exportable: multi_source_component, mode: :backup, format: :json_archive).call.data
    end

    let(:multi_component_json) do
      entries = {}
      Zip::File.open_buffer(multi_source_zip) do |zip|
        zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
      end
      JSON.parse(entries.find { |name, _| name.end_with?('component.json') }.last)
    end

    it 'has both sources on the component it backs up' do
      expect(multi_source_component.source_srgs.map(&:srg_id))
        .to contain_exactly(catalog_srg.srg_id, secondary_srg.srg_id)
    end

    it 'serializes every source SRG portably, by srg_id and version' do
      expect(multi_component_json['source_srgs']).to be_an(Array)
      # Order is part of the contract — sorted by srg_id for a stable archive.
      expect(multi_component_json['source_srgs'].pluck('srg_id'))
        .to eq([catalog_srg.srg_id, secondary_srg.srg_id].sort)
      expect(multi_component_json['source_srgs'].pluck('version'))
        .to contain_exactly(catalog_srg.version, secondary_srg.version)
      multi_component_json['source_srgs'].each do |entry|
        expect(entry.keys).to contain_exactly('srg_id', 'title', 'version')
      end
    end

    it 'lists every source SRG in the manifest component entry, for pre-flight' do
      manifest = nil
      Zip::File.open_buffer(multi_source_zip) do |zip|
        entry = zip.find { |e| e.name.end_with?('manifest.json') }
        manifest = JSON.parse(entry.get_input_stream.read)
      end

      entry = manifest['components'].find { |c| c['name'] == 'SRG Multi Source' }
      expect(entry['source_srgs'].pluck('srg_id'))
        .to contain_exactly(catalog_srg.srg_id, secondary_srg.srg_id)
    end

    it 'rebuilds every component_source_srgs row on restore' do
      target = create(:project, name: 'SRG Multi Target')
      result = Import::JsonArchiveImporter.new(zip_file: multi_source_zip, project: target,
                                               include_reviews: false).call
      expect(result).to be_success, result.errors.join('; ')

      restored = target.components.find_by(name: 'SRG Multi Source')
      expect(restored.source_srgs.map(&:srg_id))
        .to contain_exactly(catalog_srg.srg_id, secondary_srg.srg_id)
      expect(restored.based_on.srg_id).to eq(catalog_srg.srg_id)
    end

    # A secondary the destination catalog lacks costs one lineage link, not
    # the whole restore — unlike based_on, whose absence leaves nothing to
    # build. The user is told rather than left to discover it. The archive is
    # rewritten rather than the catalog emptied: the missing-SRG case is a
    # property of the destination, and shared fixtures stay untouched.
    it 'warns and still restores when the destination catalog lacks a secondary source' do
      unknown_zip = rewrite_component_json(multi_source_zip) do |json|
        json['source_srgs'].each do |entry|
          entry['srg_id'] = 'SRG-NOT-IN-THIS-CATALOG' unless entry['srg_id'] == catalog_srg.srg_id
        end
      end

      target = create(:project, name: 'SRG Missing Secondary Target')
      result = Import::JsonArchiveImporter.new(zip_file: unknown_zip, project: target,
                                               include_reviews: false).call

      expect(result).to be_success, result.errors.join('; ')
      expect(result.warnings.join(' ')).to include('SRG-NOT-IN-THIS-CATALOG')
      restored = target.components.find_by(name: 'SRG Multi Source')
      expect(restored.source_srgs.map(&:srg_id)).to contain_exactly(catalog_srg.srg_id)
    end

    # The destination may carry a different release of the secondary's SRG
    # than the source instance did — resolution falls back from the exact
    # release to any release of the same SRG, exactly as based_on does.
    it 'resolves a secondary against a different release of the same SRG' do
      shifted_zip = rewrite_component_json(multi_source_zip) do |json|
        json['source_srgs'].each do |entry|
          entry['version'] = 'V9R9' if entry['srg_id'] == secondary_srg.srg_id
        end
      end

      target = create(:project, name: 'SRG Version Shift Target')
      result = Import::JsonArchiveImporter.new(zip_file: shifted_zip, project: target,
                                               include_reviews: false).call

      expect(result).to be_success, result.errors.join('; ')
      restored = target.components.find_by(name: 'SRG Multi Source')
      expect(restored.source_srgs.map(&:srg_id))
        .to contain_exactly(catalog_srg.srg_id, secondary_srg.srg_id)
    end

    # An archive is external input: a malformed source_srgs value must be
    # ignored (based_on-only restore), never a crash — the same tolerant
    # posture build_additional_questions takes.
    it 'tolerates a malformed source_srgs value' do
      malformed_zip = rewrite_component_json(multi_source_zip) do |json|
        json['source_srgs'] = 'bogus'
      end

      target = create(:project, name: 'SRG Malformed Target')
      result = Import::JsonArchiveImporter.new(zip_file: malformed_zip, project: target,
                                               include_reviews: false).call

      expect(result).to be_success, result.errors.join('; ')
      restored = target.components.find_by(name: 'SRG Multi Source')
      expect(restored.source_srgs.map(&:srg_id)).to contain_exactly(catalog_srg.srg_id)
    end
  end

  # The key is additive: archives written before multi-parent support carry
  # no source_srgs at all. They must still restore, rebuilding the
  # single-parent set from based_on alone.
  describe 'an archive written before the source_srgs key existed' do
    let(:legacy_zip) { rewrite_component_json(source_backup_zip) { |json| json.delete('source_srgs') } }

    it 'restores from based_on alone, with no crash and no lost parent' do
      expect(component_json_from(legacy_zip)).not_to have_key('source_srgs')

      target = create(:project, name: 'SRG Legacy Archive Target')
      result = Import::JsonArchiveImporter.new(zip_file: legacy_zip, project: target,
                                               include_reviews: false).call

      expect(result).to be_success, result.errors.join('; ')
      restored = target.components.find_by(name: 'SRG Backup Test')
      expect(restored.based_on.srg_id).to eq(catalog_srg.srg_id)
      expect(restored.source_srgs.map(&:srg_id)).to contain_exactly(catalog_srg.srg_id)
    end
  end

  describe 'the restore' do
    it 'rebuilds authored SrgRules — not Rules — with derived_from and the comment intact' do
      expect(import_result).to be_success, import_result.errors.join('; ')

      expect(imported_component.document_type).to eq('srg')
      requirements = imported_component.authored_srg_rules.order(:rule_id).to_a
      expect(requirements.map(&:rule_id)).to eq(%w[000001 000002])
      expect(requirements.map { |r| r.class.name }.uniq).to eq(['SrgRule'])
      expect(imported_component.rules.count).to eq(0)
      expect(requirements.map(&:status)).to eq(['Applicable', 'Not Applicable'])
      expect(requirements.first.derived_from&.version).to eq(catalog_rule.version)

      restored_comment = Review.where(commentable_type: 'BaseRule',
                                      commentable_id: requirements.first.id,
                                      action: 'comment').first
      expect(restored_comment&.comment).to eq('Round-trip comment on an authored requirement')
    end
  end
end
