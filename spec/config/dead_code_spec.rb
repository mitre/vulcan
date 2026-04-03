# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'dead code detection' do
  # REQUIREMENT: Computed properties must be referenced in templates or other
  # computed properties. Unreferenced computed properties are dead code.

  let(:global_search) { Rails.root.join('app/javascript/components/navbar/GlobalSearch.vue').read }

  it 'GlobalSearch does not have unreferenced "show" computed property' do
    has_show_computed = global_search.match?(/show:\s*function/)
    template_section = global_search.split('<script>').first
    uses_show = template_section.match?(/\bshow\b/)

    if has_show_computed
      expect(uses_show).to be(true),
                           'GlobalSearch has a "show" computed property not referenced in its template — dead code'
    end
  end
end
