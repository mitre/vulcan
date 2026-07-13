# frozen_string_literal: true

require 'rails_helper'

# End-to-end proof that serialized has_many collections come out deterministically
# ordered (the ordering bug class — the companion change to the rule-collection
# ordering fix). Reviews order chronologically and reliably RED before the fix
# (created_at is set out of insertion order). id-ordered collections are wired to
# the unit-tested ApplicationRecord.sorted_by_id; their ordering is proven
# PRIMARILY by that unit test (deliberately shuffled input). The end-to-end
# assertions here are regression/wiring guards — a fresh test table OFTEN
# returns rows in id order already, so a behavioral RED is not guaranteed for
# them, but the guards still catch real disorder when the DB returns it (the
# project-components case did fail before the fix).
RSpec.describe 'Serialized collection ordering' do
  include_context 'components request base setup'

  describe 'GET /rules/:id (rule editor) — reviews ordered chronologically' do
    let_it_be(:rule_component) { create(:component, :skip_rules, project: project) }
    let_it_be(:rule) { create(:rule, component: rule_component) }
    let_it_be(:rev_a) { create(:review, :comment, rule: rule, user: user) }
    let_it_be(:rev_b) { create(:review, :comment, rule: rule, user: user) }
    let_it_be(:rev_c) { create(:review, :comment, rule: rule, user: user) }

    before do
      # created_at set OUT of insertion/id order so a passing test proves
      # chronological ordering, not insertion luck.
      base = Time.utc(2020, 1, 1, 12, 0, 0)
      rev_a.update_column(:created_at, base + 30.seconds) # newest
      rev_b.update_column(:created_at, base + 10.seconds) # oldest
      rev_c.update_column(:created_at, base + 20.seconds) # middle
    end

    it 'returns reviews ordered by created_at then id' do
      get "/rules/#{rule.id}"
      expect(response).to have_http_status(:success)
      ids = response.parsed_body['reviews'].pluck('id')
      expect(ids).to eq([rev_b.id, rev_c.id, rev_a.id])
    end
  end

  describe 'GET /components/:id.json (editor) — memberships ordered by id' do
    let_it_be(:m_extra1) { create(:membership, user: create(:user), membership: component, role: 'viewer') }
    let_it_be(:m_extra2) { create(:membership, user: create(:user), membership: component, role: 'author') }

    it 'returns memberships in id order' do
      get "/components/#{component.id}.json"
      expect(response).to have_http_status(:success)
      ids = response.parsed_body['memberships'].pluck('id')
      expect(ids).to eq(ids.sort)
      expect(ids).to include(m_extra1.id, m_extra2.id)
    end
  end

  describe 'GET /projects/:id.json — components and memberships ordered by id' do
    let_it_be(:comp_b) { create(:component, :skip_rules, project: project) }
    let_it_be(:comp_c) { create(:component, :skip_rules, project: project) }
    let_it_be(:proj_member) { create(:membership, user: create(:user), membership: project, role: 'viewer') }

    it 'returns components in id order' do
      get "/projects/#{project.id}.json"
      expect(response).to have_http_status(:success)
      ids = response.parsed_body['components'].pluck('id')
      expect(ids).to eq(ids.sort)
      expect(ids).to include(comp_b.id, comp_c.id)
    end

    it 'returns memberships in id order' do
      get "/projects/#{project.id}.json"
      expect(response).to have_http_status(:success)
      ids = response.parsed_body['memberships'].pluck('id')
      expect(ids).to eq(ids.sort)
      expect(ids).to include(proj_member.id)
    end
  end
end
