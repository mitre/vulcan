# User Management

Vulcan administrators can create, edit, and delete user accounts from the **Users** page (`/users`). This page is only accessible to admin users.

## Accessing the Users Page

Navigate to `/users`, or open the avatar menu at the top right and choose **Manage Users** — that entry only appears for admins.

The table lists every registered user under the columns **User**, **Type**, **Role** and **Last Sign In**. Email is not its own column: it sits in the User cell, on the hover card of the name badge.

## Creating Users

Click **Create User** to open the **Create New User** modal.

### Fields

- **Name** — required; the user's display name
- **Email** — required; must be unique across all accounts
- **Slack Member ID** — optional
- **Grant admin privileges** — optional checkbox

### Password Handling

How the new user gets their password depends on your SMTP configuration:

#### SMTP Enabled

A password setup email is sent automatically. The admin does not need to set a password — the user receives a link to create their own.

#### SMTP Disabled

Two options are available:

1. **Leave password blank** — Vulcan generates a random password and returns a **password reset link**. Copy this link and deliver it to the user (email, chat, in person). The user clicks the link to set their own password.

2. **Set password directly** — Enter a password and confirmation in the modal. The password must meet the configured [password policy](/getting-started/configuration#configure-password-policy). Use this when the user needs access immediately.

::: tip
The reset link is shown only once after user creation. If you lose it, use the **Generate Reset Link** button in the Edit User modal to create a new one.
:::

## Editing Users

Click the **edit** (pencil) icon on any user row to open the Edit User modal.

### Editable Fields

- **Name** — update the display name
- **Email** — update the email address (no re-confirmation required)
- **Slack Member ID** — update or clear it
- **Admin privileges** — toggle admin on or off

### Password Management

Password management tools are only available for **local** users (not OIDC, LDAP, or GitHub users). The provider badge in the modal shows the authentication method.

- **Send Password Reset Email** — sends a Devise reset email to the user's address. Only offered when SMTP is enabled.

- **Generate Reset Link** — creates a one-time reset URL. Copy it and deliver it to the user. Always available to admins, SMTP or not. The link expires according to Devise's `reset_password_within` setting, which Vulcan sets to 2 hours.

- **Set password manually** — expand the collapsed section to set a password directly. Requires password and confirmation fields. The password must meet the configured policy. Use this for urgent access needs.

## Account Lockout

When account lockout is enabled (default), a user account locks after too many consecutive failed login attempts — three by default. Locked users are told the account is locked when they try to sign in.

### Identifying Locked Users

On the Users page, locked accounts display a **Locked** badge (yellow) next to their role badge.

### Unlocking Accounts

Three methods are available:

1. **Admin unlock** — open the Edit User modal for a locked user. A **Status** row shows a yellow **Locked** badge and the failed-attempt count, with an **Unlock** button beside it. Click to unlock immediately. Works regardless of SMTP configuration and regardless of the unlock strategy — this is Vulcan's own endpoint, not a Devise one.

2. **Time-based auto-unlock** — the account automatically unlocks after the configured period (default: 15 minutes).

3. **Email unlock** — if SMTP is configured, the user receives an unlock link via email when their account is locked.

The default unlock strategy (`both`) is Devise's, and covers the time-based and email routes. See [Configure Account Lockout](/getting-started/configuration#configure-account-lockout) for customization.

The same Status row carries a **Lock Account** button for locking an account deliberately. An admin cannot lock their own account.

## Last-Admin Protection

Vulcan prevents you from accidentally locking out all administrators:

- You **cannot demote** the only admin user (remove their admin privileges)
- You **cannot delete** the only admin user

If you need to remove an admin, promote another user to admin first. This protection applies to both the admin UI and the API.

## Deleting Users

Click the **delete** (trash) icon on any user row. A confirmation dialog appears before deletion. This action is permanent and cannot be undone.

::: warning
Deleting a user removes their account but does not remove their contributions (reviews, comments, rule edits). Those remain attributed to the deleted user's name.
:::

## Authentication Providers

The Users table's **Type** column names each account's authentication provider as plain text — "Local User", "OIDC User", "LDAP User", "GITHUB User". The Edit User modal shows the same thing as a badge ("Local", or the provider upper-cased).

| Type | Provider | Password Management |
|-------|----------|-------------------|
| Local | Email/password | Full password tools available |
| OIDC | OpenID Connect (Okta, etc.) | No password tools — managed by identity provider |
| LDAP | LDAP directory | No password tools — managed by directory |
| GITHUB | GitHub OAuth | No password tools — managed by GitHub |

## Self-Service Password Reset

### SMTP Enabled

Users can reset their own password:
1. Click **Forgot your password?** on the login page
2. Enter their email address
3. Receive a reset link via email
4. Set a new password

### SMTP Disabled

The "Forgot your password?" page displays a message directing users to contact their Vulcan administrator. The admin can then generate a reset link or set a password from the Users page.

This applies to all email-dependent pages:
- Forgot password
- Resend confirmation instructions
- Resend unlock instructions

## Admin Bootstrap

The first admin account can be created without the Users page:

1. **Environment variables** (highest priority) — set `VULCAN_ADMIN_EMAIL` and `VULCAN_ADMIN_PASSWORD`. The admin is created automatically on `db:prepare`.

2. **First-user-admin** — when `VULCAN_FIRST_USER_ADMIN=true` (default), the first user to register or log in becomes an admin automatically.

3. **Rake task** — run `rails db:create_admin` to create an admin interactively.

See [Configuration](/getting-started/configuration) for environment variable details.

## API Tokens (Personal Access Tokens)

Users can create Personal Access Tokens for programmatic API access from the **API Tokens** page of their own account settings.

### Creating a Token

1. Open the avatar menu and choose **Profile**
2. Pick **API Tokens** from the left-hand list
3. Click **Create Token**
4. Provide a name, select scopes (`read`, `write`, or `admin`), and set an expiration date
5. Optionally add IP allowlist entries (CIDR notation) to restrict where the token can be used
6. Enter your current password to confirm
7. **Copy the token immediately** — it cannot be retrieved again

### Managing Tokens

- View all your active tokens with their last-used date and expiration
- Revoke any token by clicking the revoke button
- Tokens start with `vulcan_` for easy identification in secret scanners

### Admin Token Management

Administrators can view other users' token counts in the Users table and revoke any user's tokens from the Edit User modal. Admin revocations require an audit comment explaining the reason.

### Limits

- Maximum 20 tokens per user
- Maximum lifetime of 365 days
- `rake api_tokens:revoke_idle` revokes tokens left unused past the configured idle period (90 days by default). A token that has never been used is not idle-revoked.

See [API Authentication](/api/authentication) for usage details.

## Password Policy

Passwords for local accounts are validated against configurable complexity rules. The default follows DoD "2222" standards:

- 15 characters minimum
- 2 uppercase letters
- 2 lowercase letters
- 2 numbers
- 2 special characters

A real-time checklist shows policy compliance as the user types. See [Configure Password Policy](/getting-started/configuration#configure-password-policy) for customization options.

::: tip
OmniAuth users (OIDC, LDAP, GitHub) skip password complexity validation — their passwords are managed by the external identity provider.
:::
