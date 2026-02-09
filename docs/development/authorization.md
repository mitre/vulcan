# Authorization Architecture

Vulcan uses a deny-by-default authorization model enforced by an automated test. Every routed controller action must have an explicit `authorize_*` before_action callback — actions without one cause the test suite to fail.

## Layers

1. **Authentication** (`authenticate_user!`) — Devise, applied globally via `ApplicationController`. Answers: "Who are you?"
2. **Authorization** (`authorize_*` callbacks) — Custom, per-action. Answers: "What can you do?"

Both layers are required. Authentication alone is never sufficient for a controller action.

## Permission Hierarchy

```
admin > author > reviewer > viewer
```

Each level includes all permissions of lower levels. Permissions are scoped to either a Project or a Component.

### Global Roles

| Method | Requirement |
|--------|-------------|
| `authorize_logged_in` | Any authenticated user |
| `authorize_admin` | `current_user.admin == true` |

### Project-scoped Roles

| Method | Checks |
|--------|--------|
| `authorize_viewer_project` | `can_view_project?(@project)` |
| `authorize_author_project` | `can_author_project?(@project)` |
| `authorize_review_project` | `can_review_project?(@project)` |
| `authorize_admin_project` | `can_admin_project?(@project)` |

### Component-scoped Roles

| Method | Checks |
|--------|--------|
| `authorize_viewer_component` | `can_view_component?(@component)` |
| `authorize_author_component` | `can_author_component?(@component)` |
| `authorize_review_component` | `can_review_component?(@component)` |
| `authorize_admin_component` | `can_admin_component?(@component)` |

## Controller Authorization Map

### ProjectsController

| Action | Authorization |
|--------|---------------|
| `index` | `authorize_logged_in` |
| `search` | `authorize_logged_in` |
| `create` | `authorize_admin_or_create_permission_enabled` |
| `show` | `authorize_viewer_project` |
| `export` | `authorize_viewer_project` |
| `update` | `authorize_admin_project` |
| `destroy` | `authorize_admin_project` |

### ComponentsController

| Action | Authorization |
|--------|---------------|
| `index` | `authorize_logged_in` |
| `search` | `authorize_logged_in` |
| `based_on_same_srg` | `authorize_logged_in` |
| `show` | `authorize_component_access` (viewer if unreleased, logged_in if released) |
| `export` | `authorize_component_access` |
| `find` | `authorize_component_access` |
| `compare` | `authorize_compare_access` (checks viewer on both components) |
| `history` | `authorize_viewer_project` |
| `create` | `authorize_admin_project` |
| `update` | `authorize_author_component` + `check_admin_for_advanced_fields` |
| `destroy` | `authorize_admin_component` |

### RulesController

| Action | Authorization |
|--------|---------------|
| `index` | `authorize_viewer_component` |
| `show` | `authorize_viewer_component` |
| `related_rules` | `authorize_viewer_component` |
| `search` | `authorize_logged_in` |
| `create` | `authorize_author_component` |
| `update` | `authorize_author_component` |
| `revert` | `authorize_author_component` |
| `destroy` | `authorize_admin_component` |

### ReviewsController

| Action | Authorization |
|--------|---------------|
| `create` | `authorize_author_project` |
| `lock_controls` | `authorize_admin_component` |

### MembershipsController

| Action | Authorization |
|--------|---------------|
| `create` | `authorize_membership_create` (admin on target project/component) |
| `update` | `authorize_admin_membership` |
| `destroy` | `authorize_admin_membership` |

### ProjectAccessRequestsController

| Action | Authorization |
|--------|---------------|
| `create` | `authorize_logged_in` |
| `destroy` | `set_and_authorize_access_request` (owner or project admin) |

### SecurityRequirementsGuidesController

| Action | Authorization |
|--------|---------------|
| `index` | `authorize_logged_in` |
| `show` | `authorize_logged_in` |
| `export` | `authorize_logged_in` |
| `create` | `authorize_admin` |
| `destroy` | `authorize_admin` |

### StigsController

| Action | Authorization |
|--------|---------------|
| `index` | `authorize_logged_in` |
| `show` | `authorize_logged_in` |
| `export` | `authorize_logged_in` |
| `create` | `authorize_admin` |
| `destroy` | `authorize_admin` |

### UsersController

| Action | Authorization |
|--------|---------------|
| `index` | `authorize_admin` |
| `update` | `authorize_admin` |
| `destroy` | `authorize_admin` |

### RuleSatisfactionsController

| Action | Authorization |
|--------|---------------|
| `create` | `authorize_author_component` |
| `destroy` | `authorize_author_component` |

### Api::SearchController

| Action | Authorization |
|--------|---------------|
| `global` | `authenticate_user!` (data-scoped via `current_user.available_projects`) |

## Deny-by-Default Safety Net

`spec/requests/authorization_coverage_spec.rb` automatically verifies authorization coverage:

1. Introspects the Rails route table to find all routable controller#action pairs
2. For each, checks that at least one `authorize_*` before_action callback covers it
3. Skips Devise controllers (they handle their own auth)
4. Maintains a documented allowlist for actions that intentionally use only `authenticate_user!`

If you add a new controller action without an `authorize_*` callback, this test fails with a clear message telling you exactly which action is uncovered.

### Adding a New Action

1. Add the action to your controller
2. Add an appropriate `authorize_*` before_action for it
3. Run `bundle exec rspec spec/requests/authorization_coverage_spec.rb`
4. If the test fails, it will tell you which action needs authorization

### Rails Callback De-duplication Warning

Rails de-duplicates `before_action` callbacks with the same method name. If you write:

```ruby
before_action :authorize_admin_component, only: %i[destroy]
before_action :authorize_admin_component, only: %i[update], if: -> { ... }
```

Only the LAST declaration survives. The `destroy` action will be unprotected. Use unique method names for callbacks that need different `:only`/`:except`/`:if` configurations:

```ruby
before_action :authorize_admin_component, only: %i[destroy]
before_action :check_admin_for_advanced_fields, only: %i[update]
```

## Error Handling

`NotAuthorizedError` is rescued globally in `ApplicationController`:

- **HTML requests**: Flash alert + redirect back
- **JSON requests**: 401 status with toast message
- **API requests** (`Api::BaseController`): 403 Forbidden with JSON error
