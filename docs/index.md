# Vulcan Setup

Vulcan can be set up in a few different ways. It can be done by having a vulcan.yml file that has settings for many different configurations. If there is no vulcan.yml file then the configurations will be read in from vulcan.default.yml that has default configuration as well as the ability for the configurations to be set by environment variables.

## Index

* welcome_text: `(ENV: VULCAN_WELCOME_TEXT)(default: nil)`
* contact_email: Is the default email for ApplicationMailer to use. `(ENV: VULCAN_CONTACT_EMAIL)(default: do_not_reply@vulcan)`
* [Configure and Enable SMTP:](#configure-and-enable-smtp) Sets up the smtp mailing server
* [Configure and Enable Local Login:](#configure-and-enable-local-login) Enables user to log in as well as turn email confirmation on and off 
* [Configure and Enable LDAP:](#configure-and-enable-ldap)
* [Configure and Enable Providers:](#configure-and-enable-providers)

## Configure and Enable SMTP:
* enabled: `(ENV: VULCAN_ENABLE_SMTP)`
* settings:
    * address: Allows for a remote mail server `(ENV: VULCAN_SMTP_ADDRESS)`
    * port: Port for your mail server to run off of `(ENV: VULCAN_SMTP_PORT)`
    * domain: For specification of a HELO domain `(ENV: VULCAN_SMTP_DOMAIN)`
    * authentication: For specification of authentication type if the mail server requires it `(ENV: VULCAN_SMTP_AUTHENTICATION)`
    * tls: Enables SMTP to connect with SMTP/TLS `(ENV: VULCAN_SMTP_TLS)`
    * openssl_verify_mode: For specifying how OpenSSL checks certificates `(ENV: VULCAN_SMTP_OPENSSL_VERIFY_MODE)`
    * enable_starttls_auto: Checks if SMTP has STARTTLS enabled and starts to use it `(ENV: VULCAN_SMTP_ENABLE_STARTTLS_AUTO)`
    * user_name: For mail server authentication `(ENV: VULCAN_SMTP_SERVER_USERNAME)`
    * password: For mail server authentication `(ENV: VULCAN_SMTP_SERVER_PASSWORD)`

### SMTP Setup:
The SMTP server used for sending confirmation emails. When SMTP is set up enable `local_login: email_confirmation`.


## Configure and Enable Local login:
* enabled: Allows for users to be able to log in as a local user instead of using ldap. `(ENV: VULCAN_ENABEL_LOCAL_LOGIN)(default: true)`
* email_confirmation: Turns on email confirmation for local registration. `(ENV: VULCAN_ENABLE_EMAIL_CONFIRMATION)(default: false)`

### Local Login Setup:
Allows for users to to register and login not using external services.


## Configure and Enable LDAP:
* enabled: `(ENV: ENABLE_LDAP)(default: false)` 
* servers:
    * main:
        * host: `(ENV: VULCAN_LDAP_HOST)(default: localhost)`
        * port: Port which the LDAP server communicates through `(ENV: VULCAN_LDAP_POST)(default: 389)`
        * title: `(ENV: VULCAN_LDAP_TITLE)(default: LDAP)`
        * uid: `(ENV: VULCAN_LDAP_ATTRIBUTE)(default: uid)`
        * encryption: `(ENV: VULCAN_LDAP_ENCRYPTION)(default: plain)`
        * bind_dn: `(ENV: VULCAN_LDAP_BIND_DN)`
        * password: Passworrd to loginto the LDAP server `(ENV: VULCAN_LDAP_ADMIN_PASS)`
        * base: `(ENV: VULCAN_LDAP_BASE)`

### LDAP Setup:
Configuration for access to the active directory.


## Configure and Enable Providers

