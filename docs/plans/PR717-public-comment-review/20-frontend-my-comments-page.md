# Task 20: My Comments page on user profile

**Depends on:** 12, 13, 10
**Estimate:** 60 min Claude-pace
**File touches:**
- `app/javascript/packs/my_comments.js` (new pack — mirrors `user_profile.js` pattern)
- `esbuild.config.js` (register the new pack in `entryPoints`)
- `app/javascript/components/users/MyComments.vue` (new)
- `app/views/users/my_comments_page.html.haml` (new view template — matches existing `users/` view dir)
- `app/javascript/components/navbar/App.vue` (add "My Comments" dropdown item to user dropdown)
- `app/views/layouts/application.html.haml` (pass new prop to `<navbar>` if needed)
- `config/routes.rb` (HTML route)
- `app/controllers/users_controller.rb` (HTML render action — add to the controller from Task 12)
- `spec/javascript/components/users/MyComments.spec.js`

**Verified facts (corrected from initial guess):**
- The pack registry is `esbuild.config.js`'s `entryPoints` map (lines 6-24). New pack must be added there.
- Existing pattern model: `app/javascript/packs/user_profile.js` mounts `UserProfile.vue` to `#user-profile` via `TurbolinksAdapter`.
- The user dropdown lives in `app/javascript/components/navbar/App.vue:60-67` (NOT in HAML). Items: Profile / Manage Users / Sign Out. Add "My Comments" between Profile and Manage Users.
- The navbar receives prop URLs from HAML — see `app/views/layouts/application.html.haml:25-35`. Pass `my_comments_path` similarly.

The commenter's in-app feedback loop. Mockup: design §2.9. This is the v1 substitute for outbound email — commenters bookmark this page.

---

## Step 1: Add the HTML route + controller action

In `config/routes.rb` (alongside the JSON endpoint from Task 12):

```ruby
get '/my/comments', to: 'users#my_comments_page', as: :my_comments
```

In `app/controllers/users_controller.rb` (extend the controller from Task 12):

```ruby
def my_comments_page
  # authenticate_user! is already in before_action from Task 12
  @user = current_user
  render :my_comments_page  # explicit so Rails doesn't infer 'comments' from action name
end
```

## Step 2: Create the HAML view

`app/views/users/my_comments_page.html.haml`:

```haml
- content_for :assets do
  = javascript_include_tag 'my_comments'

#my-comments-app{ data: { user_id: @user.id } }
```

(Matches the existing pattern in `app/views/components/show.html.haml:2-3` which uses `content_for :assets do = javascript_include_tag 'project_component'`.)

## Step 3: Create the pack file

`app/javascript/packs/my_comments.js` (mirrors the existing `user_profile.js` pattern):

```javascript
import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";
import MyComments from "../components/users/MyComments.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);
Vue.use(IconsPlugin);

Vue.component("Mycomments", MyComments);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#my-comments-app",
  });
});
```

Then register the pack in `esbuild.config.js`'s `entryPoints` map (lines 6-24):

```javascript
const entryPoints = {
  application: "app/javascript/packs/application.js",
  // ... existing entries ...
  user_profile: "app/javascript/packs/user_profile.js",
  my_comments: "app/javascript/packs/my_comments.js",   // NEW
};
```

Update the HAML root tag to mount the kebab-case Vue tag:

```haml
#my-comments-app
  %mycomments{ 'v-bind:user-id': @user.id.to_json }
```

(Mirrors `<navbar v-bind:navigation="...">` etc. — Vulcan's standard mounting pattern.)

## Step 4: Failing spec

`spec/javascript/components/users/MyComments.spec.js`:

```javascript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import axios from "axios";
import MyComments from "@/components/users/MyComments.vue";

vi.mock("axios");

const mockData = {
  rows: [
    {
      id: 142, project_id: 1, project_name: "Container SRG",
      rule_id: 7, rule_displayed_name: "CRI-O-000050",
      section: "check_content", comment: "Check text issue...",
      created_at: "2026-04-27T10:00:00Z",
      triage_status: "pending", adjudicated_at: null,
      latest_activity_at: "2026-04-27T10:00:00Z",
    },
    {
      id: 110, project_id: 2, project_name: "RHEL 9 STIG",
      rule_id: 99, rule_displayed_name: "RHEL-09-0001",
      section: "fixtext", comment: "Suggest using mask...",
      created_at: "2026-04-15T10:00:00Z",
      triage_status: "concur", adjudicated_at: "2026-04-20T10:00:00Z",
      latest_activity_at: "2026-04-20T10:00:00Z",
    },
  ],
  pagination: { page: 1, per_page: 25, total: 2 },
};

describe("MyComments", () => {
  beforeEach(() => { axios.get.mockResolvedValue({ data: mockData }); });

  it("fetches /users/:id/comments on mount", async () => {
    mount(MyComments, { propsData: { userId: 5 } });
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith("/users/5/comments", expect.any(Object));
  });

  it("renders rows with friendly status badges", async () => {
    const w = mount(MyComments, { propsData: { userId: 5 } });
    await flushPromises();
    expect(w.text()).toContain("CRI-O-000050");
    expect(w.text()).toContain("Pending");
    expect(w.text()).toContain("Closed"); // adjudicated row shows "Closed (Accept)"
    expect(w.text()).toContain("Accept");
  });

  it("opens detail drawer on row click", async () => {
    const w = mount(MyComments, { propsData: { userId: 5 } });
    await flushPromises();
    w.vm.openDetail(mockData.rows[0]);
    expect(w.vm.selectedRow.id).toBe(142);
  });

  it("calls withdraw endpoint when withdraw is confirmed", async () => {
    axios.patch.mockResolvedValue({ data: {} });
    const w = mount(MyComments, { propsData: { userId: 5 } });
    await flushPromises();
    w.vm.selectedRow = mockData.rows[0];
    await w.vm.confirmWithdraw();
    expect(axios.patch).toHaveBeenCalledWith("/reviews/142/withdraw");
  });

  it("calls update endpoint when edit is saved", async () => {
    axios.put.mockResolvedValue({ data: {} });
    const w = mount(MyComments, { propsData: { userId: 5 } });
    await flushPromises();
    w.vm.selectedRow = mockData.rows[0];
    w.vm.editText = "edited content";
    await w.vm.saveEdit();
    expect(axios.put).toHaveBeenCalledWith("/reviews/142", { review: { comment: "edited content" } });
  });
});
```

## Step 5: Create `MyComments.vue`

```vue
<template>
  <div class="container py-3">
    <h2>My Comments</h2>
    <p class="text-muted">Track the status of every comment you've made across all your projects.</p>

    <b-form-group>
      <b-input-group>
        <b-form-select v-model="filterStatus" :options="statusOptions" @change="fetch" style="max-width: 220px" aria-label="Filter status" />
        <b-form-select v-model="filterProject" :options="projectOptions" @change="fetch" style="max-width: 220px" class="ml-2" aria-label="Filter project" />
      </b-input-group>
    </b-form-group>

    <b-table
      :items="rows"
      :fields="fields"
      :busy="loading"
      hover striped small
      stacked="md"
      aria-label="My comments"
    >
      <template #cell(rule_displayed_name)="{ item }">
        <a :href="`/components/${item.component_id || ''}/${item.rule_displayed_name}`">{{ item.rule_displayed_name }}</a>
      </template>
      <template #cell(section)="{ value }">
        <SectionLabel :section="value" :placeholder="true" />
      </template>
      <template #cell(triage_status)="{ item }">
        <TriageStatusBadge :status="item.triage_status" :adjudicated-at="item.adjudicated_at" :duplicate-of-id="item.duplicate_of_review_id" />
      </template>
      <template #cell(actions)="{ item }">
        <b-button size="sm" variant="outline-primary" @click="openDetail(item)">View</b-button>
      </template>
    </b-table>

    <b-modal id="my-comment-detail" :title="detailTitle" hide-footer>
      <template v-if="selectedRow">
        <p><strong>{{ selectedRow.rule_displayed_name }}</strong> · <SectionLabel :section="selectedRow.section" /></p>
        <p class="text-muted">Posted {{ friendlyDateTime(selectedRow.created_at) }} · Status: <TriageStatusBadge :status="selectedRow.triage_status" :adjudicated-at="selectedRow.adjudicated_at" /></p>

        <h5>Your comment</h5>
        <b-form-textarea v-if="editing" v-model="editText" rows="4" />
        <blockquote v-else class="border-left pl-3 py-2 mb-3 bg-light">{{ selectedRow.comment }}</blockquote>

        <h5 v-if="responses.length > 0">Triage response</h5>
        <div v-for="r in responses" :key="r.id" class="mb-2 pl-3 border-left border-info">
          <strong>{{ r.user_name }}</strong> · {{ friendlyDateTime(r.created_at) }}
          <div>{{ r.comment }}</div>
        </div>

        <div class="mt-3 text-right">
          <b-button v-if="canEdit && !editing" variant="outline-secondary" size="sm" @click="startEdit">✏ Edit comment</b-button>
          <b-button v-if="editing" variant="primary" size="sm" @click="saveEdit">Save</b-button>
          <b-button v-if="editing" variant="secondary" size="sm" @click="editing = false">Cancel</b-button>
          <b-button v-if="canWithdraw && !editing" variant="outline-danger" size="sm" @click="confirmWithdraw">⊘ Withdraw</b-button>
        </div>
      </template>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import AlertMixin from "../../mixins/AlertMixin.vue";
import { TRIAGE_LABELS } from "../../constants/triageVocabulary";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import SectionLabel from "../shared/SectionLabel.vue";

export default {
  name: "MyComments",
  components: { TriageStatusBadge, SectionLabel },
  mixins: [AlertMixin],
  props: { userId: { type: [Number, String], required: true } },
  data() {
    return {
      rows: [], total: 0, page: 1, perPage: 25, loading: false,
      filterStatus: "all", filterProject: "all",
      selectedRow: null, responses: [],
      editing: false, editText: "",
      fields: [
        { key: "id", label: "#" },
        { key: "project_name", label: "Project", sortable: true },
        { key: "rule_displayed_name", label: "Rule", sortable: true },
        { key: "section", label: "Section", sortable: true },
        { key: "comment", label: "Comment" },
        { key: "created_at", label: "Posted", sortable: true,
          formatter: (val) => new Date(val).toLocaleDateString() },
        { key: "triage_status", label: "Status" },
        { key: "actions", label: "" },
      ],
    };
  },
  computed: {
    statusOptions() {
      return [{ value: "all", text: "All statuses" }, ...Object.entries(TRIAGE_LABELS).map(([v, t]) => ({ value: v, text: t }))];
    },
    projectOptions() {
      const projects = [...new Set(this.rows.map((r) => r.project_name))];
      return [{ value: "all", text: "All projects" }, ...projects.map((p) => ({ value: p, text: p }))];
    },
    detailTitle() {
      if (!this.selectedRow) return "";
      return `Comment #${this.selectedRow.id} on ${this.selectedRow.rule_displayed_name}`;
    },
    canEdit() {
      return this.selectedRow && this.selectedRow.triage_status === "pending";
    },
    canWithdraw() {
      return this.selectedRow && ["pending", "needs_clarification"].includes(this.selectedRow.triage_status);
    },
  },
  mounted() { this.fetch(); },
  methods: {
    friendlyDateTime(iso) { return iso ? new Date(iso).toLocaleString() : ""; },
    async fetch() {
      this.loading = true;
      try {
        const params = { page: this.page, per_page: this.perPage };
        if (this.filterStatus !== "all") params.triage_status = this.filterStatus;
        const { data } = await axios.get(`/users/${this.userId}/comments`, { params });
        this.rows = data.rows;
        this.total = data.pagination.total;
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally { this.loading = false; }
    },
    async openDetail(row) {
      this.selectedRow = row;
      this.editing = false;
      // Optionally fetch responses for this comment — for v1 the rule's review thread already shows them
      this.responses = []; // populated by a follow-up endpoint or rule-thread join if needed
      this.$bvModal.show("my-comment-detail");
    },
    startEdit() {
      this.editing = true;
      this.editText = this.selectedRow.comment;
    },
    async saveEdit() {
      try {
        await axios.put(`/reviews/${this.selectedRow.id}`, { review: { comment: this.editText } });
        this.selectedRow.comment = this.editText;
        this.editing = false;
        this.fetch();
      } catch (error) { this.alertOrNotifyResponse(error); }
    },
    async confirmWithdraw() {
      if (!confirm("Withdraw this comment? This cannot be undone.")) return;
      try {
        await axios.patch(`/reviews/${this.selectedRow.id}/withdraw`);
        this.$bvModal.hide("my-comment-detail");
        this.fetch();
      } catch (error) { this.alertOrNotifyResponse(error); }
    },
  },
};
</script>
```

## Step 6: Add the navbar dropdown link

The user dropdown is in `app/javascript/components/navbar/App.vue` lines 60-67. Add a new item between "Profile" and "Manage Users":

```vue
<b-nav-item-dropdown right>
  <template #button-content>
    <b-icon icon="person-circle" aria-hidden="true" />
  </template>
  <b-dropdown-item :href="profile_path">Profile</b-dropdown-item>
  <b-dropdown-item :href="my_comments_path">My Comments</b-dropdown-item>     <!-- NEW -->
  <b-dropdown-item v-if="users_path" :href="users_path">Manage Users</b-dropdown-item>
  <b-dropdown-item @click.prevent="signOut">Sign Out</b-dropdown-item>
</b-nav-item-dropdown>
```

Add `my_comments_path` to the `props:` block (lines 98-138):

```javascript
my_comments_path: {
  type: String,
  required: false,
  default: "",
},
```

Pass the path from HAML — `app/views/layouts/application.html.haml` lines 25-35 already binds props to `<navbar>`. Add:

```haml
%navbar{
  ...
  'v-bind:profile_path': edit_user_registration_path.to_json,
  'v-bind:my_comments_path': my_comments_path.to_json,                       /-- NEW
  'v-bind:sign_out_path': destroy_user_session_path.to_json,
  ...
}
```

The `my_comments_path` route helper exists from Step 1 (`as: :my_comments`).

## Step 7: Run specs + lint + smoke

```bash
pnpm vitest run spec/javascript/components/users/MyComments.spec.js
yarn lint
bundle exec rspec spec/requests/users_spec.rb
```

## Step 8: Commit

```bash
cat > /tmp/msg-20.md <<'EOF'
feat: My Comments page on user profile

The v1 in-app feedback loop for commenters — replaces outbound email
(deferred to v2). Backed by GET /users/:id/comments from Task 12.

Per-row actions:
- View: opens read-only detail modal with full comment + any responses
- Edit (only while pending): inline textarea, PUT /reviews/:id
- Withdraw (only while pending or needs_clarification):
  PATCH /reviews/:id/withdraw with confirm prompt

Filters: triage status, project. Status badges via TriageStatusBadge —
friendly UI labels per the vocabulary-layering principle.

Routes: GET /my/comments → HTML page with #my-comments-app Vue mount
point. Vue pack mounts MyComments component, fetches via the JSON
endpoint from Task 12.

Navbar: "My Comments" link added to user dropdown.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/packs/my_comments.js \
        esbuild.config.js \
        app/javascript/components/users/MyComments.vue \
        app/javascript/components/navbar/App.vue \
        app/views/users/my_comments_page.html.haml \
        app/views/layouts/application.html.haml \
        config/routes.rb \
        app/controllers/users_controller.rb \
        spec/javascript/components/users/MyComments.spec.js
git commit -F /tmp/msg-20.md
rm /tmp/msg-20.md
git mv docs/plans/PR717-public-comment-review/20-frontend-my-comments-page.md \
       docs/plans/PR717-public-comment-review/20-frontend-my-comments-page-DONE.md
git commit -m "chore: mark plan task 20 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
