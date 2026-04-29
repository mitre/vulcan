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

  it 'has all 4 comment phase keys' do
    expect(yml['comment_phase'].keys).to match_array(%w[draft open adjudication final])
  end
end
