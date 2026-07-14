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
                                 status: 'Not Applicable', title: 'Second authored requirement')
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
