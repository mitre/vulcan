# frozen_string_literal: true

require 'rails_helper'

# Asserts that config/locales/en.yml stays in sync with the JS vocabulary
# file (app/javascript/constants/triageVocabulary.js). If you add a triage
# status to one, you MUST add it to both — this spec catches drift.
RSpec.describe 'Triage vocabulary parity (en.yml ↔ triageVocabulary.js)' do
  let(:yml) do
    YAML.load_file(Rails.root.join('config/locales/en.yml')).dig('en', 'vulcan', 'triage')
  end

  let(:js_source) do
    Rails.root.join('app/javascript/constants/triageVocabulary.js').read
  end

  let(:expected_statuses) do
    %w[pending concur concur_with_comment non_concur
       duplicate informational needs_clarification withdrawn]
  end

  it 'has all expected status keys in en.yml' do
    expect(yml['status'].keys).to match_array(expected_statuses)
  end

  it 'has all expected DISA matrix keys in en.yml' do
    expect(yml['disa_status'].keys).to match_array(expected_statuses)
  end

  it 'every status key in en.yml exists in TRIAGE_LABELS in JS' do
    yml['status'].each_key do |key|
      expect(js_source).to include("#{key}:"),
                           "JS file is missing TRIAGE_LABELS entry for `#{key}`"
    end
  end

  it 'every status key in en.yml exists in TRIAGE_GLYPHS in JS' do
    expect(js_source).to include('TRIAGE_GLYPHS')
    yml['status'].each_key do |key|
      expect(js_source).to match(/TRIAGE_GLYPHS[^}]+#{Regexp.escape(key)}:/m),
                           "JS file is missing TRIAGE_GLYPHS entry for `#{key}`"
    end
  end

  it 'has all 10 expected XCCDF section keys' do
    expected_sections = %w[title severity status fixtext check_content
                           vuln_discussion disa_metadata vendor_comments
                           artifact_description xccdf_metadata]
    expect(yml['sections'].keys).to include(*expected_sections)
  end

  it 'has the open/closed comment phase keys' do
    expect(yml['comment_phase'].keys).to match_array(%w[open closed])
  end

  it 'has the adjudicating/finalized closed_reason keys' do
    expect(yml['closed_reason'].keys).to match_array(%w[adjudicating finalized])
  end

  # proper key-set parity. The earlier
  # tests use loose substring matching ("yml key appears anywhere in JS
  # source") which doesn't catch misnamed-constant errors and never
  # checks the JS→YAML direction. This block extracts the literal key
  # set from each frozen JS constant via regex and asserts symmetric
  # set equality with the YAML namespace.
  describe 'symmetric key-set parity' do
    # Extract the keys from `export const NAME = Object.freeze({ key: ..., })`
    # in the JS source. Returns Set<String>.
    def js_const_keys(name, source)
      match = source.match(/export const #{Regexp.escape(name)} = Object\.freeze\(\{(.+?)\}\);/m)
      raise "#{name} not found in triageVocabulary.js" if match.nil?

      match[1].scan(/^\s*(\w+):/).flatten.to_set
    end

    it 'TRIAGE_LABELS in JS matches en.yml vulcan.triage.status keys' do
      yml_keys = yml['status'].keys.to_set
      js_keys  = js_const_keys('TRIAGE_LABELS', js_source)
      expect(js_keys).to eq(yml_keys),
                         'Drift between TRIAGE_LABELS and en.yml#vulcan.triage.status. ' \
                         "YAML-only: #{(yml_keys - js_keys).to_a.sort}; " \
                         "JS-only: #{(js_keys - yml_keys).to_a.sort}"
    end

    it 'TRIAGE_DISA_LABELS in JS matches en.yml vulcan.triage.disa_status keys' do
      yml_keys = yml['disa_status'].keys.to_set
      js_keys  = js_const_keys('TRIAGE_DISA_LABELS', js_source)
      expect(js_keys).to eq(yml_keys),
                         'Drift between TRIAGE_DISA_LABELS and en.yml#vulcan.triage.disa_status. ' \
                         "YAML-only: #{(yml_keys - js_keys).to_a.sort}; " \
                         "JS-only: #{(js_keys - yml_keys).to_a.sort}"
    end

    it 'SECTION_LABELS in JS matches en.yml vulcan.triage.sections (excl. "general")' do
      # `general` is a YAML-only fallback string for nil sections — there is
      # no XCCDF "general" key. SECTION_LABELS is keyed by real XCCDF
      # section names; the JS helper `sectionLabel(null)` falls back to
      # the literal "(general)" without needing a key.
      yml_keys = yml['sections'].keys.to_set - Set['general']
      js_keys  = js_const_keys('SECTION_LABELS', js_source)
      expect(js_keys).to eq(yml_keys),
                         'Drift between SECTION_LABELS and en.yml#vulcan.triage.sections. ' \
                         "YAML-only: #{(yml_keys - js_keys).to_a.sort}; " \
                         "JS-only: #{(js_keys - yml_keys).to_a.sort}"
    end

    it 'COMMENT_PHASE_LABELS in JS matches en.yml vulcan.triage.comment_phase keys' do
      yml_keys = yml['comment_phase'].keys.to_set
      js_keys  = js_const_keys('COMMENT_PHASE_LABELS', js_source)
      expect(js_keys).to eq(yml_keys),
                         'Drift between COMMENT_PHASE_LABELS and en.yml#vulcan.triage.comment_phase. ' \
                         "YAML-only: #{(yml_keys - js_keys).to_a.sort}; " \
                         "JS-only: #{(js_keys - yml_keys).to_a.sort}"
    end
  end
end
