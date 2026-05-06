# frozen_string_literal: true

require 'rails_helper'

# Asserts that the three reaction-vocabulary sources stay in sync:
# config/locales/en.yml, app/javascript/constants/reactionVocabulary.js,
# and the Ruby Reaction::KIND_LABELS / Reaction::CSV_LABELS constants.
# Mirrors triage_keys_spec.rb's parity pattern.
RSpec.describe 'Reaction vocabulary parity (en.yml ↔ reactionVocabulary.js ↔ Reaction::*_LABELS)' do
  let(:yml) do
    YAML.load_file(Rails.root.join('config/locales/en.yml')).dig('en', 'vulcan', 'reaction')
  end

  let(:js_source) do
    Rails.root.join('app/javascript/constants/reactionVocabulary.js').read
  end

  let(:expected_kinds) { %w[up down] }

  it 'has all expected kind keys in en.yml labels' do
    expect(yml['labels'].keys).to match_array(expected_kinds)
  end

  it 'has all expected kind keys in en.yml csv_labels' do
    expect(yml['csv_labels'].keys).to match_array(expected_kinds)
  end

  it 'has all expected kind keys in en.yml icons' do
    expect(yml['icons'].keys).to match_array(expected_kinds)
  end

  it 'has the closed_period_message variants (default, adjudicating, finalized)' do
    expect(yml['closed_period_message'].keys).to match_array(%w[default adjudicating finalized])
  end

  describe 'symmetric key-set parity' do
    def js_const_keys(name, source)
      match = source.match(/export const #{Regexp.escape(name)} = Object\.freeze\(\{(.+?)\}\);/m)
      raise StandardError, "#{name} not found in reactionVocabulary.js" if match.nil?

      match[1].scan(/^\s*(\w+):/).flatten.to_set
    end

    it 'REACTION_LABELS in JS matches en.yml vulcan.reaction.labels' do
      yml_keys = yml['labels'].keys.to_set
      js_keys = js_const_keys('REACTION_LABELS', js_source)
      expect(js_keys).to eq(yml_keys)
    end

    it 'REACTION_ICONS in JS matches en.yml vulcan.reaction.icons' do
      yml_keys = yml['icons'].keys.to_set
      js_keys = js_const_keys('REACTION_ICONS', js_source)
      expect(js_keys).to eq(yml_keys)
    end

    it 'Reaction::KIND_LABELS Ruby constant matches en.yml vulcan.reaction.labels' do
      expect(Reaction::KIND_LABELS.keys.to_set).to eq(yml['labels'].keys.to_set)
    end

    it 'Reaction::CSV_LABELS Ruby constant matches en.yml vulcan.reaction.csv_labels' do
      expect(Reaction::CSV_LABELS.keys.to_set).to eq(yml['csv_labels'].keys.to_set)
    end
  end
end
