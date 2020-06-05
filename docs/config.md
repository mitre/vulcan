# Vulcan Configuration

## Index
* [Configure SMTP:](#configure-smtp) Sets up the smtp mailing server
* [Configure Local Login:](#configure-local-login) Enables user to log in as well as turn email confirmation on and off 
* [Configure LDAP:](#configure-ldap)
* [Configure Providers:](#configure-providers)

## Configure SMTP:
* **enabled:** `(ENV: VULCAN_ENABLE_SMTP)`
* **settings:**
    * **address:** Allows for a remote mail server `(ENV: VULCAN_SMTP_ADDRESS)`
    * **port:** Port for your mail server to run off of `(ENV: VULCAN_SMTP_PORT)`
    * **domain:** For specification of a HELO domain `(ENV: VULCAN_SMTP_DOMAIN)`
    * **authentication:** For specification of authentication type if the mail server requires it `(ENV: VULCAN_SMTP_AUTHENTICATION)`
    * **tls:** Enables SMTP to connect with SMTP/TLS `(ENV: VULCAN_SMTP_TLS)`
    * **openssl_verify_mode:** For specifying how OpenSSL checks certificates `(ENV: VULCAN_SMTP_OPENSSL_VERIFY_MODE)`
    * **enable_starttls_auto:** Checks if SMTP has STARTTLS enabled and starts to use it `(ENV: VULCAN_SMTP_ENABLE_STARTTLS_AUTO)`
    * **user_name:** For mail server authentication `(ENV: VULCAN_SMTP_SERVER_USERNAME)`
    * **password:** For mail server authentication `(ENV: VULCAN_SMTP_SERVER_PASSWORD)`

## Configure Local Login
* **enabled:** Allows for users to be able to log in as a local user instead of using ldap. `(ENV: VULCAN_ENABEL_LOCAL_LOGIN)(default: true)`
* **email_confirmation:** Turns on email confirmation for local registration. `(ENV: VULCAN_ENABLE_EMAIL_CONFIRMATION)(default: false)`

## Configure LDAP
* **enabled:** `(ENV: ENABLE_LDAP)(default: false)` 
* **servers:**
    * **main:**
        * **host:** `(ENV: VULCAN_LDAP_HOST)(default: localhost)`
        * **port:** Port which the LDAP server communicates through `(ENV: VULCAN_LDAP_POST)(default: 389)`
        * **title:** `(ENV: VULCAN_LDAP_TITLE)(default: LDAP)`
        * **uid:** Attribute for the username `(ENV: VULCAN_LDAP_ATTRIBUTE)(default: uid)`
        * **encryption:** `(ENV: VULCAN_LDAP_ENCRYPTION)(default: plain)`
        * **bind_dn:** The DN of the user you will bind with `(ENV: VULCAN_LDAP_BIND_DN)`
        * **password:** Password to log into the LDAP server `(ENV: VULCAN_LDAP_ADMIN_PASS)`
        * **base:** The point where a server will search for users `(ENV: VULCAN_LDAP_BASE)`

## Example Vulcan.yml
```
defaults: &defaults
  welcome_text:
  contact_email:
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