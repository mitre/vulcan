## Vulcan Setup

Vulcan can be set up in a few different ways. It can be done by having a vulcan.yml file that has settings for many different configurations. If there is no vulcan.yml file then the configurations will be read in from vulcan.default.yml that has default configuration as well as the ability for the configurations to be set by environment variables.

### Index

* welcome_text: 
* contact_email: Is the default email for ApplicationMailer to use.
* [Configure and Enable SMTP:](#configure-and-enable-smtp) Sets up the smtp mailing server
* [Configure and Enable Local Login:](#configure-and-enable-local-login) Enables user to log in as well as turn email confirmation on and off 
* [Configure and Enable LDAP:](#configure-and-enable-ldap)
* [Configure and Enable Providers:](#configure-and-enable-providers)

#### Configure and Enable SMTP:
* enabled: `(ENV: ENABLE_SMTP)`
* settings:
    * address: `(ENV: MAILER_ADDRESS)`
    * port: `(ENV: MAILER_PORT)`
    * domain: `(ENV: MAILER_DOMAIN)`
    * authentication: `(ENV: MAILER_AUTHENTICATION)`
    * tls: `(ENV: MAILER_TLS)`
    * openssl_verify_mode: `(ENV: MAILER_OPENSSL_VERIFY_MODE)`
    * enable_starttls_auto: `(ENV: MAILER_ENABLE_STARTTLS_AUTO)`
    * user_name: `(ENV: MAILER_SMTP_SERVER_USERNAME)`
    * password: `(ENV: MAILER_SMTP_SERVER_PASSWORD)`

#### Configure and Enable Local login:
* enabled: Allows for users to be able to log in as a local user instead of using ldap. `(ENV: ENABEL_LOCAL_LOGIN)(default: true)`
* email_confirmation: Turns on email confirmation for local registration. `(default: true)`

#### Configure and Enable LDAP:
* enabled: `(ENV: ENABLE_LDAP)(default: false)` 
* servers:
    * main:
        * host: `(ENV: LDAP_HOST)(default: localhost)`
        * port: `(ENV: LDAP_POST)(default: 389)`
        * title: `(ENV: LDAP_TITLE)(default: LDAP)`
        * uid: `(ENV: LDAP_ATTRIBUTE)(default: uid)`
        * encryption: `(ENV: LDAP_ENCRYPTION)(default`
        * bind_dn: `(ENV: LDAP_BIND_DN)`
        * password: `(ENV: LDAP_ADMIN_PASS)`
        * base: `(ENV: LDAP_BASE)`

#### Configure and Enable Providers

