# User Management

Vulcan administrators can create, edit, and delete user accounts from the **Users** page (`/users`). This page is only accessible to admin users.

## Accessing the Users Page

Navigate to `/users` or click the user icon in the navigation bar. You must be logged in as an admin.

The page shows all registered users with their name, email, authentication provider, role, and last sign-in date.

## Creating Users

Click **Create User** to open the creation modal.

### Required Fields

- **Name** — the user's display name
- **Email** — must be unique across all accounts
- **Admin** — optional checkbox to grant admin privileges

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
- **Admin** — toggle admin privileges on or off

### Password Management

Password management tools are only available for **local** users (not OIDC, LDAP, or GitHub users). The provider badge in the modal shows the authentication method.

#### SMTP Enabled

- **Send Password Reset Email** — sends a Devise reset email to the user's address

#### SMTP Disabled

- **Generate Reset Link** — creates a one-time reset URL. Copy it and deliver it to the user. The link expires according to Devise's `reset_password_within` setting (default: 6 hours).

- **Set password manually** — expand the collapsed section to set a password directly. Requires password and confirmation fields. The password must meet the configured policy. Use this for urgent access needs.

## Deleting Users

Click the **delete** (trash) icon on any user row. A confirmation dialog appears before deletion. This action is permanent and cannot be undone.

::: warning
Deleting a user removes their account but does not remove their contributions (reviews, comments, rule edits). Those remain attributed to the deleted user's name.
:::

## Authentication Providers

Each user has an authentication provider shown as a badge:

| Badge | Provider | Password Management |
|-------|----------|-------------------|
| Local | Email/password | Full password tools available |
| OIDC | OpenID Connect (Okta, etc.) | No password tools — managed by identity provider |
| LDAP | LDAP directory | No password tools — managed by directory |
| GitHub | GitHub OAuth | No password tools — managed by GitHub |

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
