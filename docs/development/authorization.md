# Authorization Architecture

Vulcan uses a deny-by-default authorization model enforced by an automated test. Every routed controller action must have an explicit `authorize_*` before_action callback — actions without one cause the test suite to fail.

## Layers

1. **Authentication** (`authenticate_user!`) — Devise, applied globally via `ApplicationController`. Answers: "Who are you?"
2. **Authorization** (`authorize_*` callbacks) — Custom, per-action. Answers: "What can you do?"

Both layers are required. Authentication alone is never sufficient for a controller action.

## Role Hierarchy

```
Site Admin (global)
    └── can do everything on every project and component

Project/Component Roles (scoped):
    admin > reviewer > author > viewer
```

Each level includes all permissions of lower levels. A project **admin** can do everything a reviewer, author, and viewer can do. Roles are assigned per-project or per-component via `Membership` records.

**Available roles**: `viewer`, `author`, `reviewer`, `admin`

### Site Admin vs Project/Component Admin

- **Site admin** (`User#admin == true`): Full access to everything — all projects, all components, user management, SRG/STIG uploads. Set via database or admin bootstrap.
- **Project admin**: Full access to one project — can update/delete the project, manage members, create/delete components. Automatically assigned when a user creates a project.
- **Component admin**: Full access to one component — can delete the component, lock/unlock controls, manage component members. Can be assigned by project admin.

### Effective Permissions (Components)

Components have **dual membership** — a user's effective permission on a component is the **higher** of:

1. Their project-level membership role (inherited)
2. Their component-level membership role (direct)

Example: A user with `viewer` role on a project but `admin` role on a specific component within that project has **admin** permissions on that component.

This is computed by `User#effective_permissions(component)` and passed to Vue as the `effective_permissions` prop.

## User-Facing Permissions Summary

### Projects

| Action | Who |
|--------|-----|
| Browse project list | Any logged-in user |
| Create a project | Site admin, or any user when `create_permission_enabled` is on |
| View project details | Project member (viewer+) or site admin |
| Export project | Project member (viewer+) or site admin |
| Update project name/description | Project admin or site admin |
| Delete a project | Project admin or site admin |
| Manage project members | Project admin or site admin |

When a user creates a project, they are automatically assigned the **admin** role on that project. This means project creators can update, delete, and manage members on their own projects without being a site admin.

### Components

| Action | Who |
|--------|-----|
| View (unreleased) | Project member (viewer+) or site admin |
| View (released) | Any logged-in user |
| Create | Project admin or site admin |
| Edit rules | Component author+ (not if released) |
| Edit advanced fields (status, severity) | Component admin or site admin |
| Delete | Component admin or site admin |
| Lock/unlock controls | Component admin or site admin |
| Compare components | Viewer on both components (or released) |

**Released components** are read-only — even authors and reviewers cannot edit rules on a released component. Only site admins bypass this restriction.

### Rules

| Action | Who |
|--------|-----|
| View rules | Component viewer+ |
| Create/update/revert | Component author+ |
| Delete | Component admin or site admin |
| Submit review | Component reviewer+ or project author+ |

### Memberships

| Action | Who |
|--------|-----|
| Add members to project | Project admin or site admin |
| Add members to component | Component admin or site admin |
| Update member role | Admin of the target project/component |
| Remove a member | Admin of the target project/component |

### Access Requests

| Action | Who |
|--------|-----|
| Request access to a discoverable project | Any logged-in user |
| Cancel own access request | The requesting user |
| Approve/deny access requests | Project admin or site admin |

### SRGs and STIGs

| Action | Who |
|--------|-----|
| View and export | Any logged-in user |
| Upload new | Site admin only |
| Delete | Site admin only |

### Users

| Action | Who |
|--------|-----|
| View user list | Site admin only |
| Update user (promote to admin, etc.) | Site admin only |
| Delete user | Site admin only |

### Search

| Action | Who |
|--------|-----|
| Global search | Any logged-in user (results scoped to user's accessible projects) |

## Project Visibility

Projects have a `visibility` setting:

- **Discoverable**: Appears in project list for all users. Non-members can see the project name/description and request access.
- **Hidden**: Only visible to project members and site admins.

Visibility does NOT grant access to project contents — only membership does.

## Authorization Methods Reference

### Global

| Method | Requirement |
|--------|-------------|
| `authorize_logged_in` | Any authenticated user |
| `authorize_admin` | `current_user.admin == true` (site admin) |
| `authorize_admin_or_create_permission_enabled` | Site admin OR `Settings.project.create_permission_enabled` |

### Project-scoped

| Method | Checks |
|--------|--------|
| `authorize_viewer_project` | `can_view_project?(@project)` — site admin OR membership with any role |
| `authorize_author_project` | `can_author_project?(@project)` — site admin OR membership with author+ |
| `authorize_review_project` | `can_review_project?(@project)` — site admin OR membership with reviewer+ |
| `authorize_admin_project` | `can_admin_project?(@project)` — site admin OR membership with admin |

### Component-scoped

| Method | Checks |
|--------|--------|
| `authorize_viewer_component` | `can_view_component?(@component)` — site admin OR effective_permissions is any role |
| `authorize_author_component` | `can_author_component?(@component)` — site admin OR effective_permissions author+ (blocked if released) |
| `authorize_review_component` | `can_review_component?(@component)` — site admin OR effective_permissions reviewer+ |
| `authorize_admin_component` | `can_admin_component?(@component)` — site admin OR effective_permissions admin |

### Special

| Method | Checks |
|--------|--------|
| `authorize_component_access` | Viewer if unreleased, logged_in if released |
| `authorize_compare_access` | Viewer on both components being compared |
| `check_admin_for_advanced_fields` | Admin required only when updating status/severity fields |
| `authorize_membership_create` | Admin on the target project or component |
| `set_and_authorize_access_request` | Request owner or project admin |

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
