# Task 22: UpdateComponentDetailsModal — Comment Phase fieldset

**Depends on:** 04
**Estimate:** 25 min Claude-pace
**File touches:**
- `app/javascript/components/components/UpdateComponentDetailsModal.vue` (modify — this is the actual "Edit Component Details" form, opened from the comp-details slideover)
- `app/controllers/components_controller.rb` (extend `component_update_params` at lines 597-606)
- `spec/requests/components_spec.rb`
- `spec/javascript/components/components/UpdateComponentDetailsModal.spec.js`

**Verified facts (ground truth):**
- The "Edit Component" form is **`UpdateComponentDetailsModal.vue`**, opened from inside the `sidebar-details` slideover at `ControlsSidepanels.vue:36-40` (where it's mounted with `v-if="canAdmin"` so admin-only).
- The modal currently submits these fields via `axios.put('/components/:id', ...)`: `name, version, release, title, description, prefix, admin_name, admin_email` (UpdateComponentDetailsModal.vue:155-170).
- The backend `component_update_params` is at `app/controllers/components_controller.rb:597-606`. Currently permits: `:released, :name, :version, :release, :title, :prefix, :description, :admin_name, :admin_email, :advanced_fields` plus nested `additional_questions_attributes` and `component_metadata_attributes`.

The admin-facing fieldset that toggles comment phase + sets dates. Mockup: design §2.8.

---

## Step 1: Permit the params on backend

In `app/controllers/components_controller.rb` at line 597, the existing `component_update_params` method permits a flat list. Add three keys:

```ruby
def component_update_params
  # rubocop:disable Rails/StrongParametersExpect -- params.expect breaks nested array attributes (issue #692)
  params.require(:component).permit(
    :released, :name, :version, :release, :title, :prefix,
    :description, :admin_name, :admin_email, :advanced_fields,
    :comment_phase, :comment_period_starts_at, :comment_period_ends_at,    # NEW
    additional_questions_attributes: [:id, :name, :question_type, :_destroy, { options: [] }],
    component_metadata_attributes: { data: {} }
  )
  # rubocop:enable Rails/StrongParametersExpect
end
```

## Step 2: Backend spec

Append to `spec/requests/components_spec.rb`:

```ruby
describe 'PATCH /components/:id with comment_phase params' do
  let_it_be(:admin_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }
  before_all do
    create(:membership, user: admin_user, membership: project, role: 'admin')
  end

  before do
    Rails.application.reload_routes!
    sign_in admin_user
  end

  it 'updates comment_phase' do
    patch "/components/#{component.id}", params: {
      component: { comment_phase: 'open', comment_period_starts_at: 1.day.ago, comment_period_ends_at: 30.days.from_now }
    }, as: :json

    expect(response).to have_http_status(:success)
    expect(component.reload.comment_phase).to eq('open')
  end

  it 'rejects invalid comment_phase' do
    patch "/components/#{component.id}", params: {
      component: { comment_phase: 'invalid_phase' }
    }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
```

Run, expect FAIL → permit → expect PASS.

## Step 3: Frontend fieldset — UpdateComponentDetailsModal.vue

Three changes to `app/javascript/components/components/UpdateComponentDetailsModal.vue`:

### 3a: Extend `data()` (lines 96-110) with new fields:

```javascript
data: function () {
  return {
    name: this.component.name,
    version: this.component.version,
    // ... existing fields ...
    comment_phase: this.component.comment_phase || 'draft',                  // NEW
    comment_period_starts_at: this.component.comment_period_starts_at,       // NEW (date string)
    comment_period_ends_at: this.component.comment_period_ends_at,           // NEW (date string)
  };
},
```

### 3b: Extend `resetModal()` (lines 112-122) to reset the new fields:

```javascript
resetModal: function () {
  this.name = this.component.name;
  // ... existing resets ...
  this.comment_phase = this.component.comment_phase || 'draft';              // NEW
  this.comment_period_starts_at = this.component.comment_period_starts_at;   // NEW
  this.comment_period_ends_at = this.component.comment_period_ends_at;       // NEW
},
```

### 3c: Extend the payload-attribute list (lines 156-167) with the new keys:

```javascript
[
  "name", "version", "release", "title", "description", "prefix",
  "admin_name", "admin_email",
  "comment_phase", "comment_period_starts_at", "comment_period_ends_at",   // NEW
].forEach((attr) => {
  if (payload.component[attr] !== this[attr]) {
    payload.component[attr] = this[attr];
  }
});
```

### 3d: Add the fieldset to the template (after the existing PoC field, before line 71):

```vue
<b-form-group label="Public Comment Period" label-class="font-weight-bold">
  <b-form-radio-group
    v-model="comment_phase"
    :options="phaseOptions"
    stacked
    aria-label="Comment phase"
  />
  <div class="row mt-2">
    <div class="col">
      <label for="comment-period-start">Start date</label>
      <b-form-input id="comment-period-start" v-model="comment_period_starts_at" type="date" />
    </div>
    <div class="col">
      <label for="comment-period-end">End date</label>
      <b-form-input id="comment-period-end" v-model="comment_period_ends_at" type="date" />
    </div>
  </div>
  <b-alert show variant="info" class="mt-2 mb-0 small">
    During <strong>Open</strong>, viewers can post comments and admins/authors triage them.
    During <strong>Adjudication</strong>, no new comments are accepted but triage continues.
    v1 has no outbound email — commenters track status via "My Comments" on their profile.
  </b-alert>
</b-form-group>
```

Add a `computed` block to the modal's `export default` (the modal currently has no `computed` — add one):

```javascript
import { COMMENT_PHASE_LABELS } from "../../constants/triageVocabulary";

// inside export default:
computed: {
  phaseOptions() {
    return Object.entries(COMMENT_PHASE_LABELS).map(([value, text]) => ({ value, text }));
  },
},
```

**Important pattern note**: the modal binds directly to `this.<attr>` (no wrapping `form` object — see existing fields like `v-model="name"`). Match that — use `v-model="comment_phase"`, NOT `v-model="form.comment_phase"`.

## Step 4: Frontend spec

```javascript
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import UpdateComponentDetailsModal from "@/components/components/UpdateComponentDetailsModal.vue";

describe("UpdateComponentDetailsModal — comment phase fieldset", () => {
  const baseComponent = { id: 1, name: "x", version: "1", release: "1", title: "x",
                          description: "", prefix: "AB-CD", admin_name: "", admin_email: "",
                          comment_phase: "draft" };

  it("renders a radio group with the four phase options", () => {
    const w = mount(UpdateComponentDetailsModal, { propsData: { component: baseComponent } });
    expect(w.text()).toContain("Draft");
    expect(w.text()).toContain("Open for comment");
    expect(w.text()).toContain("Adjudication");
    expect(w.text()).toContain("Final");
  });

  it("binds v-model to this.comment_phase (not form.comment_phase)", () => {
    const w = mount(UpdateComponentDetailsModal, {
      propsData: { component: { ...baseComponent, comment_phase: "open" } },
    });
    expect(w.vm.comment_phase).toBe("open");
  });
});
```

## Step 5: Run, lint, commit

```bash
bundle exec rspec spec/requests/components_spec.rb -e "comment_phase"
pnpm vitest run spec/javascript/components/components/UpdateComponentDetailsModal.spec.js
yarn lint

cat > /tmp/msg-22.md <<'EOF'
feat: Comment Phase fieldset on UpdateComponentDetailsModal

Admin-facing fieldset (Component admin or higher) for toggling the
public-comment phase and setting period dates. Per DESIGN §2.8.

Backend: extends component_update_params (components_controller.rb:597-606)
to permit :comment_phase, :comment_period_starts_at, :comment_period_ends_at.
Inclusion validator on Component (Task 04) rejects invalid phases at
the model layer.

Frontend: extends UpdateComponentDetailsModal.vue's data{} + resetModal +
payload-attribute list with the three new keys. Adds a b-form-group
"Public Comment Period" with stacked radios for the 4 phases (driven by
COMMENT_PHASE_LABELS from triageVocabulary.js) and two date inputs.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/controllers/components_controller.rb \
        app/javascript/components/components/UpdateComponentDetailsModal.vue \
        spec/requests/components_spec.rb \
        spec/javascript/components/components/UpdateComponentDetailsModal.spec.js
git commit -F /tmp/msg-22.md
rm /tmp/msg-22.md
git mv docs/plans/PR717-public-comment-review/22-frontend-edit-component-comment-phase.md \
       docs/plans/PR717-public-comment-review/22-frontend-edit-component-comment-phase-DONE.md
git commit -m "chore: mark plan task 22 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
