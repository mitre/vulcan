# Admin Panel Design Document

## Overview

Full admin panel with sidebar navigation at `/admin/*` namespace.

## Decisions Summary

| Decision | Answer |
|----------|--------|
| Admin panel scope | Full panel with sidebar |
| Settings | Read-only viewer for now |
| Devise lockable | Yes (migration required) |
| Invite users | Yes |
| URL structure | `/admin/*` (STIGs/SRGs still viewable at `/stigs`, `/srgs`) |
| User detail layout | Slideout/Drawer (modern approach) |

## URL Structure

### Admin Routes (admin-only)
```
/admin                    # Dashboard
/admin/users              # User management
/admin/audit              # Audit log viewer
/admin/settings           # Read-only settings viewer
/admin/content/benchmarks # Unified benchmark management (STIGs, SRGs, Components)
```

### Public Routes (authenticated users)
```
/benchmarks               # Unified view (STIGs, SRGs, Released Components)
/benchmarks?tab=stig      # STIGs tab
/benchmarks?tab=srg       # SRGs tab
/benchmarks?tab=component # Components tab (released only for non-admins)
```

### Notes on Component Management
- Components are NOT uploaded directly - they are created within Projects
- Admin can delete released components from `/admin/content/benchmarks`
- Component upload button is intentionally hidden (unlike STIGs/SRGs)
- Non-admins see only released components in the public benchmarks view

## Admin Panel Layout

```
┌──────────────────────────────────────────────────────────────────┐
│  VULCAN                           [Search] [🔔] [👤]             │
├────────────┬─────────────────────────────────────────────────────┤
│            │                                                      │
│  Dashboard │  [Main Content Area]                                 │
│            │                                                      │
│  Users     │                                                      │
│            │                                                      │
│  Audit Log │                                                      │
│            │                                                      │
│  Content   │                                                      │
│   └ STIGs  │                                                      │
│   └ SRGs   │                                                      │
│            │                                                      │
│  Settings  │                                                      │
│            │                                                      │
│  ─────────│                                                      │
│  ← Back   │                                                      │
│            │                                                      │
└────────────┴─────────────────────────────────────────────────────┘
```

## Page Designs

### 1. Dashboard (`/admin`)

```
┌─────────────────────────────────────────────────────────────────┐
│  Admin Dashboard                                                 │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐│
│  │ 42 Users    │  │ 15 Projects │  │ 8 STIGs     │  │ 5 SRGs  ││
│  │ 35 Local    │  │ 3 new/month │  │ 2 uploaded  │  │         ││
│  │ 7 OIDC      │  │             │  │ this month  │  │         ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘│
│                                                                  │
│  Recent Activity                                                 │
│  ┌──────────────────────────────────────────────────────────────┤
│  │ • John Doe updated rule RHEL-09-123456           2 min ago  ││
│  │ • Jane Smith joined project "Container STIG"    15 min ago  ││
│  │ • Admin uploaded U_RHEL_9_V2R6_STIG.zip         1 hour ago  ││
│  │ • Bob Wilson was promoted to admin              3 hours ago ││
│  └──────────────────────────────────────────────────────────────┤
└─────────────────────────────────────────────────────────────────┘
```

### 2. Users (`/admin/users`)

**Main View:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Users                                         [+ Invite User]  │
├─────────────────────────────────────────────────────────────────┤
│  [Search users...]            Filter: [All Types ▾] [All Roles]│
├─────────────────────────────────────────────────────────────────┤
│  Name          Email              Type    Role    Status    ⋮  │
│  ───────────────────────────────────────────────────────────────│
│  John Doe      john@example.com   Local   Admin   Active    ⋮  │
│  Jane Smith    jane@example.com   OIDC    User    Active    ⋮  │
│  Bob Wilson    bob@example.com    LDAP    User    Locked    ⋮  │
│  ───────────────────────────────────────────────────────────────│
│                              [1] [2] [3] ... [10]               │
└─────────────────────────────────────────────────────────────────┘
```

**User Detail Slideout (click row to open):**
```
                                    ┌─────────────────────────────┐
                                    │  × John Doe                 │
                                    ├─────────────────────────────┤
                                    │  [Overview] [Projects]      │
                                    │  [Activity] [Security]      │
                                    ├─────────────────────────────┤
                                    │                             │
                                    │  OVERVIEW TAB:              │
                                    │  Email: john@example.com    │
                                    │  Type: Local User           │
                                    │  Role: Admin                │
                                    │  Created: Jan 15, 2024      │
                                    │  ─────────────────────────  │
                                    │  Sign-in Stats:             │
                                    │  Last sign in: 2 hours ago  │
                                    │  Sign in count: 145         │
                                    │  Last IP: 192.168.1.100     │
                                    │  ─────────────────────────  │
                                    │  Account Status:            │
                                    │  ✓ Email confirmed          │
                                    │  ✓ Account active           │
                                    │                             │
                                    └─────────────────────────────┘
```

**Slideout Tabs:**

- **Overview**: Email, provider, created_at, sign-in stats, account status
- **Projects**: Table of memberships with project name, role, joined date
- **Activity**: Audit log filtered to this user only
- **Security**: 
  - Change Role (admin/user dropdown)
  - Send Password Reset (local users only)
  - Lock/Unlock Account
  - Resend Confirmation Email
  - Delete User

### 3. Audit Log (`/admin/audit`)

```
┌─────────────────────────────────────────────────────────────────┐
│  Audit Log                                        [Export CSV]  │
├─────────────────────────────────────────────────────────────────┤
│  [Search...]  [User ▾]  [Action ▾]  [Type ▾]  [Date Range]     │
├─────────────────────────────────────────────────────────────────┤
│  Time         User        Action    Entity           Changes   │
│  ───────────────────────────────────────────────────────────────│
│  2 min ago    John Doe    update    Rule RHEL-09-1   status... │
│  15 min ago   Jane Smith  create    Membership       joined... │
│  1 hour ago   Admin       create    Stig             uploaded  │
│  3 hours ago  System      update    User Bob Wilson  admin...  │
│  ───────────────────────────────────────────────────────────────│
│                              [1] [2] [3] ... [50]               │
└─────────────────────────────────────────────────────────────────┘
```

### 4. Settings (`/admin/settings`) - Read Only

```
┌─────────────────────────────────────────────────────────────────┐
│  System Settings                                 (Read Only)    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Authentication                                                  │
│  ┌──────────────────────────────────────────────────────────────┤
│  │ Local Login         ✓ Enabled                               ││
│  │ Email Confirmation  ✗ Disabled                              ││
│  │ User Registration   ✓ Enabled                               ││
│  │ Session Timeout     60 minutes                              ││
│  └──────────────────────────────────────────────────────────────┤
│                                                                  │
│  LDAP                                                           │
│  ┌──────────────────────────────────────────────────────────────┤
│  │ Status              ✗ Disabled                              ││
│  └──────────────────────────────────────────────────────────────┤
│                                                                  │
│  OIDC                                                           │
│  ┌──────────────────────────────────────────────────────────────┤
│  │ Status              ✓ Enabled                               ││
│  │ Provider            Okta                                    ││
│  │ Issuer              https://company.okta.com                ││
│  └──────────────────────────────────────────────────────────────┤
│                                                                  │
│  Email (SMTP)                                                   │
│  ┌──────────────────────────────────────────────────────────────┤
│  │ Status              ✓ Enabled                               ││
│  │ Server              smtp.example.com:587                    ││
│  └──────────────────────────────────────────────────────────────┤
│                                                                  │
│  Integrations                                                   │
│  ┌──────────────────────────────────────────────────────────────┤
│  │ Slack               ✗ Disabled                              ││
│  └──────────────────────────────────────────────────────────────┤
│                                                                  │
│  ℹ️ Settings are configured via vulcan.yml or environment       │
│     variables. Changes require application restart.             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Order

### Phase 1: Backend Foundation
1. Add Devise `:lockable` migration
2. Add `locked_at`, `failed_attempts`, `unlock_token` columns to users
3. Create `/admin` namespace in routes
4. Create `Admin::BaseController` with admin authorization
5. Create `Admin::UsersController` with detail endpoint
6. Add user invite functionality

### Phase 2: Admin Layout
1. Create `AdminLayout.vue` with sidebar
2. Create admin router configuration
3. Create `AdminSidebar.vue` component
4. Add `/admin` entry to navbar for admins

### Phase 3: Users Page
1. Migrate `Users.vue` to `/admin/users`
2. Create `UserSlideout.vue` component
3. Implement tabs: Overview, Projects, Activity, Security
4. Add security actions (lock, unlock, reset password, invite)

### Phase 4: Dashboard
1. Create `AdminDashboard.vue`
2. Add stats API endpoint
3. Add recent activity feed

### Phase 5: Audit Log
1. Create `AuditLog.vue` page
2. Add filters and search
3. Add export functionality

### Phase 6: Settings Viewer
1. Create `SettingsViewer.vue`
2. Create API endpoint to return safe settings (no secrets)

### Phase 7: Content Management
1. Move STIG upload/delete to `/admin/content/stigs`
2. Move SRG upload/delete to `/admin/content/srgs`
3. Keep `/stigs` and `/srgs` as read-only for all authenticated users

## Components Needed

### New Components
- `AdminLayout.vue` - Main layout with sidebar
- `AdminSidebar.vue` - Navigation sidebar
- `AdminDashboard.vue` - Dashboard page
- `UserSlideout.vue` - User detail drawer
- `UserOverviewTab.vue` - Overview tab content
- `UserProjectsTab.vue` - Memberships tab content  
- `UserActivityTab.vue` - User-specific audit log
- `UserSecurityTab.vue` - Security actions
- `InviteUserModal.vue` - Invite user form
- `AuditLogPage.vue` - Centralized audit viewer
- `SettingsViewerPage.vue` - Read-only settings display

### Reusable Components (already exist)
- `BaseTable.vue` - For all tables
- `ActionMenu.vue` - Row actions
- `DeleteModal.vue` - Confirmations
- `SearchInput.vue` - Search fields

## API Endpoints Needed

### New Endpoints
```
GET    /admin/stats              # Dashboard stats
GET    /admin/users/:id          # User detail with memberships
POST   /admin/users/:id/lock     # Lock user account
POST   /admin/users/:id/unlock   # Unlock user account
POST   /admin/users/:id/reset_password  # Send reset email
POST   /admin/users/:id/resend_confirmation
POST   /admin/users/invite       # Invite new user
GET    /admin/audit              # Paginated audit log
GET    /admin/settings           # Safe settings (no secrets)
```

## Migration Required

```ruby
class AddLockableToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :unlock_token, :string
    add_column :users, :locked_at, :datetime
    
    add_index :users, :unlock_token, unique: true
  end
end
```

Update `User` model:
```ruby
devise :database_authenticatable, :registerable, :rememberable,
       :recoverable, :confirmable, :trackable, :validatable,
       :lockable  # ADD THIS
```

## Future Enhancements

### Messaging Integrations
Currently the User model has `slack_user_id` for Slack notifications. Future plan is to refactor to support multiple messaging providers:

- **Current**: `slack_user_id` (Slack only)
- **Future**: `messaging_id` + `messaging_provider` (Slack, Microsoft Teams, Signal)

This will require:
1. Database migration to rename/add columns
2. Update User model
3. Update all API responses
4. Update frontend types and components
5. Add provider selection in user settings
