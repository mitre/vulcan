# Task 26: Admin move-to-rule — relocate a misplaced comment

**Depends on:** 25 (admin actions disclosure already wired)
**Estimate:** 60 min Claude-pace
**File touches:**
- `app/controllers/reviews_controller.rb` (new `move_to_rule` action)
- `config/routes.rb` (route)
- `app/models/review.rb` (validation: target rule in same component;
  replies follow parent semantics)
- `app/javascript/components/components/CommentTriageModal.vue` (admin
  picker + action)
- `app/javascript/components/components/RulePicker.vue` (new — embedded
  rule picker scoped to component)
- `spec/requests/reviews_controller_spec.rb` (extend)
- `spec/javascript/components/components/CommentTriageModal.spec.js` (extend)
- `spec/javascript/components/components/RulePicker.spec.js` (new)

## Why this task exists

Commenters sometimes post on the wrong rule:
- They meant the baseline (rule X) but posted on the implementation (rule Y) — or vice versa
- They confused two similarly-named rules
- A rule was renamed/moved after the comment was posted

Mark-as-duplicate (Task 24) handles the case where two comments exist
and one should consolidate. Move-to-rule handles the case where the
comment is genuinely misplaced and needs to be relocated to its
correct home.

## Verified facts

- `Review.belongs_to :rule` (FK; nullable: false)
- `Review` has `responding_to_review_id` for thread replies
- `VulcanAuditable` audits `rule_id` changes automatically
- Existing pattern from Task 25 for admin-only authorization +
  audit-comment-required actions

## Design decisions

- **Admin-only authorization** (mirrors Task 25)
- **Same-component scope**: target rule must be in the same component
  as the source. Cross-component moves are out of scope (data integrity
  + permissions concerns).
- **Replies follow parent**: when moving comment X (with replies
  Y, Z), Y.rule_id and Z.rule_id also move to the new rule. Use a
  transaction to ensure atomicity.
- **Cycle in threads** (a reply that has replies of its own): walk the
  full subtree; move all descendants together.
- **Audit comment required** explaining the move
- **Triage state preserved**: rule_id changes; triage_status,
  adjudicated_at, etc. are unchanged. The triage decision came with the
  comment to its new home.
- **`duplicate_of_review_id` preserved**: if the comment was previously
  marked as duplicate of canonical Z, that pointer survives the move
  (Z lives on its own rule independent of the move).

## Step 1: Failing spec — backend

```ruby
describe 'PATCH /reviews/:id/move_to_rule' do
  let(:component) { create(:component) }
  let(:project) { component.project }
  let(:rule_a) { create(:rule, component: component) }
  let(:rule_b) { create(:rule, component: component) }
  let(:other_component) { create(:component, project: project) }
  let(:rule_other) { create(:rule, component: other_component) }
  let(:admin) { create(:user) }
  let(:author) { create(:user) }
  let(:commenter) { create(:user) }

  before do
    Membership.create!(user: admin, membership: project, role: 'admin')
    Membership.create!(user: author, membership: project, role: 'author')
    Membership.create!(user: commenter, membership: project, role: 'viewer')
  end

  let!(:parent_review) do
    Review.create!(rule: rule_a, user: commenter, action: 'comment',
                   comment: 'misplaced concern', triage_status: 'pending')
  end
  let!(:reply_review) do
    Review.create!(rule: rule_a, user: author, action: 'comment',
                   comment: 'thanks for raising', triage_status: 'pending',
                   responding_to_review_id: parent_review.id)
  end

  context 'as admin' do
    before { sign_in admin }

    it 'reassigns the parent review and ALL replies to the new rule (atomic)' do
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: rule_b.id, audit_comment: 'belongs on rule B' },
            as: :json
      expect(response).to have_http_status(:ok)
      expect(parent_review.reload.rule_id).to eq(rule_b.id)
      expect(reply_review.reload.rule_id).to eq(rule_b.id)
    end

    it 'rejects when target rule is in a different component' do
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: rule_other.id, audit_comment: 'x' },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['toast']['message']).to include(/same component/i)
    end

    it 'rejects when target rule is the same as the source rule' do
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: rule_a.id, audit_comment: 'x' },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects when target rule does not exist' do
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: 999_999, audit_comment: 'x' },
            as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects when audit_comment is blank' do
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: rule_b.id, audit_comment: '' },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'preserves triage_status and adjudication on move' do
      parent_review.update!(triage_status: 'concur', adjudicated_at: 1.day.ago,
                            adjudicated_by_id: author.id)
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: rule_b.id, audit_comment: 'x' }, as: :json
      parent_review.reload
      expect(parent_review.rule_id).to eq(rule_b.id)
      expect(parent_review.triage_status).to eq('concur')
      expect(parent_review.adjudicated_at).to be_present
    end

    it 'preserves duplicate_of_review_id pointer on move' do
      canonical = Review.create!(rule: rule_b, user: author, action: 'comment',
                                 comment: 'canon', triage_status: 'pending')
      parent_review.update!(triage_status: 'duplicate', duplicate_of_review_id: canonical.id)
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: rule_b.id, audit_comment: 'x' }, as: :json
      expect(parent_review.reload.duplicate_of_review_id).to eq(canonical.id)
    end

    it 'records the move in the audit log on parent + each reply' do
      expect do
        patch "/reviews/#{parent_review.id}/move_to_rule",
              params: { rule_id: rule_b.id, audit_comment: 'x' }, as: :json
      end.to change { parent_review.reload.audits.count }.by_at_least(1)
        .and change { reply_review.reload.audits.count }.by_at_least(1)
    end

    it 'is atomic — if any descendant move fails, none of them apply' do
      # Force a validation failure on the second move by stubbing
      allow_any_instance_of(Review).to receive(:save).and_wrap_original do |original, *args|
        original.call(*args).tap do
          raise ActiveRecord::Rollback if instance_of?(Review) && rule_id == rule_b.id
        end
      end
      # ... or simpler: monkey-patch reply to fail validation
      # (Adapt the test to whatever transactional pattern the controller uses)
    end
  end

  context 'as non-admin' do
    before { sign_in author }
    it 'returns 403' do
      patch "/reviews/#{parent_review.id}/move_to_rule",
            params: { rule_id: rule_b.id, audit_comment: 'x' }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

## Step 2: Implement — controller

```ruby
def move_to_rule
  target_rule_id = params[:rule_id].to_i
  audit_comment = params[:audit_comment].to_s.strip

  if audit_comment.blank?
    return render json: validation_toast('Audit comment required for move'),
                  status: :unprocessable_entity
  end
  if target_rule_id == @review.rule_id
    return render json: validation_toast('Target rule is the same as the source'),
                  status: :unprocessable_entity
  end

  target_rule = Rule.find_by(id: target_rule_id)
  return head :not_found unless target_rule
  unless target_rule.component_id == @review.rule.component_id
    return render json: validation_toast('Target rule must be in the same component'),
                  status: :unprocessable_entity
  end

  # Walk the full reply subtree and move atomically.
  ActiveRecord::Base.transaction do
    move_review_subtree!(@review, target_rule.id, audit_comment)
  end

  render json: success_payload(@review.reload)
end

private

def move_review_subtree!(review, new_rule_id, audit_comment)
  review.audit_comment = "Moved to rule #{new_rule_id}: #{audit_comment}"
  review.update!(rule_id: new_rule_id)
  Review.where(responding_to_review_id: review.id).find_each do |child|
    move_review_subtree!(child, new_rule_id, audit_comment)
  end
end
```

## Step 3: Implement — frontend RulePicker

`app/javascript/components/components/RulePicker.vue`:

```vue
<template>
  <div>
    <b-form-input
      v-model="query"
      placeholder="Search by rule name (CNTR-01-...)..."
      debounce="200"
      aria-label="Search target rule"
      size="sm"
      class="mb-2"
    />
    <ul class="list-unstyled mb-0" style="max-height: 240px; overflow-y: auto">
      <li v-if="filteredRules.length === 0" class="text-muted small">
        No matching rules in this component.
      </li>
      <li
        v-for="r in filteredRules"
        :key="r.id"
        :data-test="`target-rule-${r.id}`"
        class="border rounded p-2 mb-1 clickable"
        @click="$emit('selected', r.id)"
      >
        <strong>{{ r.displayed_name }}</strong>
        <small class="text-muted ml-2">{{ truncate(r.title, 80) }}</small>
      </li>
    </ul>
  </div>
</template>

<script>
export default {
  name: "RulePicker",
  props: {
    rules: { type: Array, required: true },        // [{id, displayed_name, title}]
    excludeRuleId: { type: [Number, String], required: true },
  },
  data() { return { query: "" }; },
  computed: {
    filteredRules() {
      const q = this.query.toLowerCase().trim();
      return this.rules
        .filter((r) => r.id !== Number(this.excludeRuleId))
        .filter((r) => !q || r.displayed_name.toLowerCase().includes(q) ||
                       (r.title || "").toLowerCase().includes(q))
        .slice(0, 25);
    },
  },
  methods: {
    truncate(s, n) { return s && s.length > n ? `${s.slice(0, n)}…` : s; },
  },
};
</script>
```

## Step 4: Wire RulePicker into CommentTriageModal

In the admin actions section (added in Task 25), add a "Move to rule"
button. Click reveals RulePicker; selection + audit comment + Confirm
calls PATCH /reviews/:id/move_to_rule.

## Step 5: Frontend specs

Comprehensive specs for RulePicker (search, exclude self, click emits)
and the CommentTriageModal flow (admin sees Move action, picker
appears, submit calls correct endpoint).

## Step 6: Run all impacted specs, lint, vocabulary, commit, DONE

## Acceptance criteria

- [ ] New endpoint PATCH /reviews/:id/move_to_rule
- [ ] Auth: admin only
- [ ] Audit comment required
- [ ] Target rule must be in same component (server enforces)
- [ ] Target rule must differ from source (server enforces)
- [ ] All replies follow parent on move (atomic transaction)
- [ ] triage_status, adjudicated_*, duplicate_of preserved on move
- [ ] Audit log captures the move on parent + each reply
- [ ] RulePicker filters by query, excludes source rule
- [ ] Admin UI in CommentTriageModal exposes Move action
- [ ] All specs green
