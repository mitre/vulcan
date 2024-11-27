# Vulcan Configuration

Vulcan can be set up in a few different ways. It can be done by having a vulcan.yml file that has settings for many different configurations. If there is no vulcan.yml file then the configurations will be read in from vulcan.default.yml that has default configuration as well as the ability for the configurations to be set by environment variables (see [installation](index.md)).

[**Installation**](index.md) | [**Configuration**](config.md)

## Index

- [Configure Welcome Text and Contact Email](#configure-welcome-text-and-contact-email)
- [Configure SMTP:](#configure-smtp) Sets up the smtp mailing server
- [Configure Local Login:](#configure-local-login) Enables user to log in as well as turn email confirmation on and off
- [Configure User Registration:](#configure-user-registration) Enables user sign-ups
- [Configure Project Create Permissions:](#configure-project-create-permissions) Logged-In users can create projects
- [Configure LDAP:](#configure-ldap)
- [Configure OIDC:](#configure-oidc)
- [Configure Slack:](#configure-slack)
- [Configure Providers:](#configure-providers)

## Configure Welcome Text and Contact Email:

- **welcome_text:** Welcome text is the text shown on the homepage below the "What is Vulcan" blurb on the homepage. It can be configured by the administrator to provide users with any information that may be relevant to their access and usage of the Vulcan application. `(ENV: VULCAN_WELCOME_TEXT)(default: nil)`
- **contact_email:** Contact email is the reply email shown to users on confirmation and notification emails. By default this will revert to `do_not_reply@vulcan` if no email is specified. Is the default email for ApplicationMailer to use. `(ENV: VULCAN_CONTACT_EMAIL)(default: do_not_reply@vulcan)`
- **app_url:** Allows hyper-linking of vulcan urls when notifications are sent `(ENV: VULCAN_APP_URL)`

## Configure SMTP:

- **enabled:** `(ENV: VULCAN_ENABLE_SMTP)`
- **settings:**
  - **address:** Allows for a remote mail server `(ENV: VULCAN_SMTP_ADDRESS)`
  - **port:** Port for your mail server to run off of `(ENV: VULCAN_SMTP_PORT)`
  - **domain:** For specification of a HELO domain `(ENV: VULCAN_SMTP_DOMAIN)`
  - **authentication:** For specification of authentication type if the mail server requires it `(ENV: VULCAN_SMTP_AUTHENTICATION)`
  - **tls:** Enables SMTP to connect with SMTP/TLS `(ENV: VULCAN_SMTP_TLS)`
  - **openssl_verify_mode:** For specifying how OpenSSL checks certificates `(ENV: VULCAN_SMTP_OPENSSL_VERIFY_MODE)`
  - **enable_starttls_auto:** Checks if SMTP has STARTTLS enabled and starts to use it `(ENV: VULCAN_SMTP_ENABLE_STARTTLS_AUTO)`
  - **user_name:** For mail server authentication `(ENV: VULCAN_SMTP_SERVER_USERNAME)`
  - **password:** For mail server authentication `(ENV: VULCAN_SMTP_SERVER_PASSWORD)`

## Configure Local Login

- **enabled:** Allows for users to be able to log in as a local user instead of using ldap. `(ENV: VULCAN_ENABEL_LOCAL_LOGIN)(default: true)`
- **email_confirmation:** Turns on email confirmation for local registration. `(ENV: VULCAN_ENABLE_EMAIL_CONFIRMATION)(default: false)`
- **session_timeout:** Automatically logs user out after a period of time of inactivity in minutes. `(ENV: VULCAN_SESSION_TIMEOUT)(default: 60)`

## Configure User Registration
- **enabled:** Allows users to register themselves on the Vulcan app. `(ENV: VULCAN_ENABLE_USER_REGISTRATION)(default: true)`

## Configure Project Create Permissions
- **create_permission_enabled:** Allows any logged-in users to create new projects in Vulcan if enabled, otherwise only Vulcan Admins are allowed to create projects. `(ENV: VULCAN_PROJECT_CREATE_PERMISSION_ENABLED)(default: true)`

## Configure LDAP

- **enabled:** `(ENV: ENABLE_LDAP)(default: false)`
- **servers:**
  - **main:**
    - **host:** `(ENV: VULCAN_LDAP_HOST)(default: localhost)`
    - **port:** Port which the LDAP server communicates through `(ENV: VULCAN_LDAP_POST)(default: 389)`
    - **title:** `(ENV: VULCAN_LDAP_TITLE)(default: LDAP)`
    - **uid:** Attribute for the username `(ENV: VULCAN_LDAP_ATTRIBUTE)(default: uid)`
    - **encryption:** `(ENV: VULCAN_LDAP_ENCRYPTION)(default: plain)`
    - **bind_dn:** The DN of the user you will bind with `(ENV: VULCAN_LDAP_BIND_DN)`
    - **password:** Password to log into the LDAP server `(ENV: VULCAN_LDAP_ADMIN_PASS)`
    - **base:** The point where a server will search for users `(ENV: VULCAN_LDAP_BASE)`

## Configure OIDC

- **enabled:** `(ENV: VULCAN_ENABLE_OIDC)(default: false)`
- **strategy:** :openid_connect `Omniauth Strategy for working with OIDC providers`
- **title:** : Description or Title for the OIDC Provider `(ENV: VULCAN_OIDC_PROVIDER_TITLE)`
- **args:** 
  - **name:** Name of the OIDC provider `(ENV: VULCAN_OIDC_PROVIDER_TITLE)`
  - **scope:** Which OpenID scope to include (:openid is always required) `default: [:openid]`
  - **uid_field:** The field of the user info response to be used as a unique id
  - **response_type:** Which OAuth2 response type to use with the authorization request `default: [:code]`
  - **issuer:** Root url for the authorization server `(ENV: VULCAN_OIDC_ISSUER_URL)`
  - **client_auth_method:** Which authentication method to use to authenticate your app with the authorization server `default: :secret`
  - **client_signing_alg:** Signing algorithms, specify the base64-encoded secret used to sign the JWT token `(ENV: VULCAN_OIDC_CLIENT_SIGNING_ALG)`
  - **nonce:** 
  - **client_options:**
      - **port:** The port for the authorization server `(ENV: VULCAN_OIDC_PORT)(default: 443)`
      - **scheme:** The http scheme to use `(ENV: VULCAN_OIDC_SCHEME)(default: https)`
      - **host:** The host for the authorization server	 `(ENV: VULCAN_OIDC_HOST)`
      - **identifier:** The OIDC client_id `(ENV: VULCAN_OIDC_CLIENT_ID)`
      - **secret:** The OIDC client secret `(ENV: VULCAN_OIDC_CLIENT_SECRET)`
      - **redirect_uri:** The OIDC authorization callback url in vulcan app. `(ENV: VULCAN_OIDC_REDIRECT_URI)`
      - **authorization_endpoint:** The authorize endpoint on the authorization server `(ENV: VULCAN_OIDC_AUTHORIZATION_URL)`
      - **token_endpoint:** The token endpoint on the authorization server `(ENV: VULCAN_OIDC_TOKEN_URL)`
      - **userinfo_endpoint:** The user info endpoint on the authorization server `(ENV: VULCAN_OIDC_USERINFO_URL)`
      - **jwks_uri:** The jwks_uri on the authorization server `(ENV: VULCAN_OIDC_JWKS_URI)`
      - **post_logout_redirect_uri:** '/'

## Configure Slack

- **enabled:** Enable Integration with Slack `(ENV: VULCAN_ENABLE_SLACK_COMMS)(default: false)`
- **api_token:** Slack Authentication token bearing required scopes.`(ENV: VULCAN_SLACK_API_TOKEN)`
- **channel_id:**  Slack Channel, private group, or IM channel to send message to. Can be an encoded ID, or a name. `(ENV: VULCAN_SLACK_CHANNEL_ID)`

## Example Vulcan.yml

```
defaults: &defaults
  welcome_text:
  contact_email:
  app_url:
  smtp:
    enabled:
    settings:
      address:
      port:
      domain:
      authentication:
      tls:
      openssl_verify_mode:
      enable_starttls_auto:
      user_name:
      password:
  local_login:
    enabled:
    email_confirmation:
  ldap:
    enabled:
    servers:
      main:
        host:
        port:
        title:
        uid:
        encryption:
        bind_dn:
        password:
        base:
  oidc:
    enabled: 
    strategy:
    title:
    args:
      name: 
      scope:
      uid_field: 
      response_type:
      issuer: 
      client_auth_method:
      client_signing_alg:
      nonce:
      client_options:
        port:
        scheme:
        host:
        identifier:
        secret:
        redirect_uri:
        authorization_endpoint:
        token_endpoint:
        userinfo_endpoint:
        jwks_uri:
        post_logout_redirect_uri:
  slack:
    enabled:
    api_token:
    channel_id:
  providers:
    # - { name: 'github',
    #     app_id: '<APP_ID>',
    #     app_secret: '<APP_SECRET>',
    #     args: { scope: 'user:email' } }

development:
  <<: *defaults
test:
  <<: *defaults
production:
  <<: *defaults
```
