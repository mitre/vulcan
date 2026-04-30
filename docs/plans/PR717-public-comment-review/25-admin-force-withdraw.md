# Task 25: Admin force-withdraw — override commenter intent on a comment

**Depends on:** 12 (existing withdraw endpoint as reference)
**Estimate:** 30 min Claude-pace
**File touches:**
- `app/controllers/reviews_controller.rb` (new `admin_withdraw` action)
- `config/routes.rb` (route)
- `app/javascript/components/components/CommentTriageModal.vue` (admin actions section)
- `spec/requests/reviews_controller_spec.rb` (extend)
- `spec/javascript/components/components/CommentTriageModal.spec.js` (extend)

## Why this task exists

Today, only the original commenter can withdraw a comment (Task 12).
That works for normal cases but leaves admins without recourse for:
- Spam comments
- Comments containing PII / sensitive data the admin must remove
- Comments left after a commenter's account was disabled
- Cleanup before a published-component release

Force-withdraw is an admin-only override that flips the comment to
`withdrawn` with admin attribution + a required audit comment.

## Verified facts

- `Review#withdraw` action exists today (Task 12) with auth via the
  commenter equality check
- `Review.triage_status` already supports `'withdrawn'`
- `VulcanAuditable` audits `triage_status` changes automatically
- Authorization: `authorize_admin_component` is the project's
  established pattern for admin-only actions

## Design decisions

- **Admin-only authorization** via `authorize_admin_component`
- **Required audit comment** explaining the action — captured via
  `audit_comment` on the model save (VulcanAuditable handles
  persistence)
- **Sets adjudicated_at + adjudicated_by_id** so the comment is
  effectively closed (admin took final action)
- **Even on already-adjudicated comments** — admins can override
  prior triage state in extreme cases
- **No commenter notification in v1** — email is out of scope. The
  audit log captures the action for compliance.
- **UI placement**: admin actions section in CommentTriageModal,
  collapsed by default with a clear "Admin actions" disclosure so
  triagers don't accidentally click

## Step 1: Failing spec — backend

```ruby
describe 'PATCH /reviews/:id/admin_withdraw' do
  let(:component) { create(:component) }
  let(:project) { component.project }
  let(:rule) { create(:rule, component: component) }
  let(:commenter) { create(:user) }
  let(:admin) { create(:user) }
  let(:author) { create(:user) }

  before do
    Membership.create!(user: commenter, membership: project, role: 'viewer')
    Membership.create!(user: admin, membership: project, role: 'admin')
    Membership.create!(user: author, membership: project, role: 'author')
  end

  let!(:review) do
    Review.create!(rule: rule, user: commenter, action: 'comment',
                   comment: 'spam', triage_status: 'pending')
  end

  context 'as admin' do
    before { sign_in admin }

    it 'sets triage_status=withdrawn + adjudicated attribution + audit comment' do
      patch "/reviews/#{review.id}/admin_withdraw",
            params: { audit_comment: 'spam content removed by admin' },
            as: :json
      expect(response).to have_http_status(:ok)
      review.reload
      expect(review.triage_status).to eq('withdrawn')
      expect(review.adjudicated_at).to be_present
      expect(review.adjudicated_by_id).to eq(admin.id)
    end

    it 'rejects when audit_comment is blank' do
      patch "/reviews/#{review.id}/admin_withdraw",
            params: { audit_comment: '' }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'allows overriding an already-adjudicated review' do
      review.update!(triage_status: 'concur', adjudicated_at: 1.day.ago, adjudicated_by_id: author.id)
      patch "/reviews/#{review.id}/admin_withdraw",
            params: { audit_comment: 'overriding prior decision' }, as: :json
      expect(response).to have_http_status(:ok)
      review.reload
      expect(review.triage_status).to eq('withdrawn')
      expect(review.adjudicated_by_id).to eq(admin.id)
    end

    it 'records the admin override in the audit log' do
      expect do
        patch "/reviews/#{review.id}/admin_withdraw",
              params: { audit_comment: 'admin remove' }, as: :json
      end.to change { review.reload.audits.count }.by_at_least(1)
      latest = review.audits.last
      expect(latest.comment).to include('admin remove')
    end
  end

  context 'as author (not admin)' do
    before { sign_in author }
    it 'returns 403' do
      patch "/reviews/#{review.id}/admin_withdraw",
            params: { audit_comment: '...' }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'as commenter (not admin)' do
    before { sign_in commenter }
    it 'returns 403' do
      patch "/reviews/#{review.id}/admin_withdraw",
            params: { audit_comment: '...' }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'unauthenticated' do
    it 'redirects to sign in' do
      patch "/reviews/#{review.id}/admin_withdraw",
            params: { audit_comment: '...' }, as: :json
      expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
    end
  end
end
```

## Step 2: Implement — controller + routes

`config/routes.rb`:

```ruby
resources :reviews, only: [] do
  member do
    patch :triage
    patch :adjudicate
    patch :withdraw
    patch :admin_withdraw  # NEW
  end
end
```

`app/controllers/reviews_controller.rb`:

```ruby
before_action :set_review_for_admin_withdraw, only: %i[admin_withdraw]
before_action :authorize_admin_component_for_review, only: %i[admin_withdraw]

def admin_withdraw
  audit_comment = params[:audit_comment].to_s.strip
  if audit_comment.blank?
    return render json: validation_toast('Audit comment required for admin withdraw'),
                  status: :unprocessable_entity
  end

  @review.audit_comment = "Admin force-withdraw: #{audit_comment}"
  @review.update!(
    triage_status: 'withdrawn',
    adjudicated_at: Time.current,
    adjudicated_by_id: current_user.id
  )
  render json: success_payload(@review)
end

private

def set_review_for_admin_withdraw
  @review = Review.includes(:rule).find(params[:id])
end

def authorize_admin_component_for_review
  unless ProjectMember.role_at_least?(current_user, @review.rule.component.project, 'admin')
    head :forbidden
  end
end
```

(Adapt the role check to whatever existing pattern the controller
uses — `authorize_admin_project` etc.)

## Step 3: Failing spec — frontend

Extend `CommentTriageModal.spec.js`:

```javascript
describe("CommentTriageModal — admin actions (PR #717 Task 25)", () => {
  it("renders the 'Admin actions' disclosure when current user has admin role", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: {
        review: { ...sampleReview, triage_status: 'pending' },
        effectivePermissions: 'admin',
      },
    });
    expect(w.text()).toContain("Admin actions");
  });

  it("does NOT render admin actions when role < admin", () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: {
        review: { ...sampleReview, triage_status: 'pending' },
        effectivePermissions: 'author',
      },
    });
    expect(w.text()).not.toContain("Admin actions");
  });

  it("calls PATCH /reviews/:id/admin_withdraw with the audit comment when 'Force-withdraw' is submitted", async () => {
    axios.patch.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview, effectivePermissions: 'admin' },
    });
    await w.find('[data-test="open-admin-actions"]').trigger("click");
    await w.find('[data-test="admin-action-force-withdraw"]').trigger("click");
    await w.setData({ adminAuditComment: 'spam removed' });
    await w.find('[data-test="admin-action-confirm"]').trigger("click");
    await flushPromises(w);
    expect(axios.patch).toHaveBeenCalledWith(
      `/reviews/${sampleReview.id}/admin_withdraw`,
      expect.objectContaining({ audit_comment: 'spam removed' }),
    );
  });

  it("disables 'Confirm' until the audit comment is provided", async () => {
    const w = mount(CommentTriageModal, {
      localVue,
      propsData: { review: sampleReview, effectivePermissions: 'admin' },
    });
    await w.find('[data-test="open-admin-actions"]').trigger("click");
    await w.find('[data-test="admin-action-force-withdraw"]').trigger("click");
    expect(w.find('[data-test="admin-action-confirm"]').attributes("disabled")).toBeDefined();
    await w.setData({ adminAuditComment: 'reason' });
    expect(w.find('[data-test="admin-action-confirm"]').attributes("disabled")).toBeUndefined();
  });
});
```

## Step 4: Implement — frontend

Add a collapsible "Admin actions" disclosure section near the bottom
of `CommentTriageModal.vue`'s body:

```vue
<div v-if="canAdminAct" class="mt-3 border-top pt-3">
  <b-button
    variant="link"
    size="sm"
    class="p-0"
    data-test="open-admin-actions"
    :aria-expanded="String(adminActionsOpen)"
    @click="adminActionsOpen = !adminActionsOpen"
  >
    <b-icon icon="shield-lock" class="text-warning" />
    Admin actions {{ adminActionsOpen ? '▴' : '▾' }}
  </b-button>
  <div v-show="adminActionsOpen" class="mt-2 p-2 border rounded bg-light">
    <p class="text-muted small mb-2">
      Use sparingly — admin overrides are recorded in the audit log.
    </p>
    <b-button
      v-if="!adminActionInProgress"
      size="sm"
      variant="outline-warning"
      data-test="admin-action-force-withdraw"
      @click="adminActionInProgress = 'force-withdraw'"
    >
      <b-icon icon="x-octagon" /> Force-withdraw
    </b-button>
    <div v-else>
      <b-form-textarea
        v-model="adminAuditComment"
        rows="2"
        placeholder="Reason (audit log)..."
        size="sm"
      />
      <div class="mt-2">
        <b-button size="sm" @click="cancelAdminAction">Cancel</b-button>
        <b-button
          size="sm"
          variant="warning"
          data-test="admin-action-confirm"
          :disabled="!adminAuditComment.trim()"
          @click="submitAdminAction"
        >
          Confirm force-withdraw
        </b-button>
      </div>
    </div>
  </div>
</div>
```

Plus the script-side methods + computed `canAdminAct` (checks
`effectivePermissions === 'admin'` via RoleComparisonMixin).

## Step 5: Run, lint, vocabulary check, commit, DONE rename

Standard pattern.

## Acceptance criteria

- [ ] New endpoint PATCH /reviews/:id/admin_withdraw
- [ ] Auth: admin only (others get 403)
- [ ] Audit comment required (blank → 422)
- [ ] Sets triage_status=withdrawn + adjudicated_at + adjudicated_by_id=admin
- [ ] Allowed even on already-adjudicated reviews
- [ ] Audit log records the admin action with the audit comment
- [ ] CommentTriageModal "Admin actions" disclosure visible only when role=admin
- [ ] Confirm button disabled until audit comment is non-blank
- [ ] No vocabulary leaks
- [ ] All impacted specs green
