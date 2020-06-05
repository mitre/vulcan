# Vulcan Setup

Vulcan can be set up in a few different ways. It can be done by having a vulcan.yml file that has settings for many different configurations. If there is no vulcan.yml file then the configurations will be read in from vulcan.default.yml that has default configuration as well as the ability for the configurations to be set by environment variables.

## Index

* [Configure and Setup Welcome Text and Contact Email:](#configure-and-setup-welcome-text-and-contact-email:)
* [Configure and Enable SMTP:](#configure-and-enable-smtp) Sets up the smtp mailing server
* [Configure and Enable Local Login:](#configure-and-enable-local-login) Enables user to log in as well as turn email confirmation on and off 
* [Configure and Enable LDAP:](#configure-and-enable-ldap)
* [Configure and Enable Providers:](#configure-and-enable-providers)

## Configuration Breakdown
[Configuration](config.md)

## Configure and Setup Welcome Text and Contact Email:
* **welcome_text:** Welcome text is the text shown on the homepage below the "What is Vulcan" blurb on the homepage. It can be configured by the administrator to provide users with any information that may be relevant to their access and usage of the Vulcan application. `(ENV: VULCAN_WELCOME_TEXT)(default: nil)`
* **contact_email:** Contact email is the reply email shown to users on confirmation and notification emails. By default this will revert to `do_not_reply@vulcan` if no email is specified. Is the default email for ApplicationMailer to use. `(ENV: VULCAN_CONTACT_EMAIL)(default: do_not_reply@vulcan)`

## Configure and Enable SMTP:
### SMTP Setup:
To enable SMTP you will need to add your configuration file to `config/vulcan.yml` or pass in the specifications as environment variables. When SMTP is set up you should enable `local_login: email_confirmation` so users must confirm their email to continue.

### SMTP Configuration
[Configuration](config.md#configure-smtp)



## Configure and Enable Local login:
### Local Login Setup:
Allows for users to to register and login not using external services.

### Local Login Configuration
[Configuration](config.md#configure-local-login)



## Configure and Enable LDAP:
### LDAP Setup:
To enable LDAP you will need to add your configuration file to `config/vulcan.yml` or pass in the specifications as environment variables. 

### LDAP Configuration:
[Configuration](config.md#configure-ldap)



## Configure and Enable Providers

